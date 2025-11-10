//
//  DishSyncService.swift
//  Random4Dinner
//
//  Created by Oleg Podрез on 31.03.25.
//  Обновлено: reconciliation удалений, устойчивость Storage, фильтры по userId/groupId.
//  Safe dedup + duplicate logging to avoid Dictionary(uniqueKeysWithValues:) crashes.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData
import UIKit
import FirebaseStorage

@MainActor
final class DishSyncService {
    static let shared = DishSyncService()
    private let db = Firestore.firestore()
    private init() {}

    // MARK: - Public API

    /// Полная синхронизация: импорт -> reconciliation удалений -> экспорт локальных изменений.
    func syncDishes(context: ModelContext, userGroups: [String]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Нет авторизации"])
        }

        print("[DishSync] start userId=\(userId), groups=\(userGroups)")

        // 1) Импорт доступных блюд с сервера (по userId и groupIds)
        let remoteDishes = try await fetchAllAvailableDishes(userId: userId, groupIds: userGroups)
        // Defensive dedupe before any dictionary work
        let uniqueRemoteDishes = Self.removeDuplicates(remoteDishes)

        // 2) Мёрдж в локальную базу (upsert)
        let localDishes = try context.fetch(FetchDescriptor<Dish>())

        // Build localDict safely (tolerate duplicate local ids; log and overwrite)
        var localDict: [UUID: Dish] = [:]
        var localDupCount = 0
        var localDupIdsLogged = Set<UUID>()
        for d in localDishes {
            if localDict.updateValue(d, forKey: d.id) != nil {
                localDupCount += 1
                if localDupIdsLogged.insert(d.id).inserted {
                    print("[DishSync][dup-local] duplicate local id encountered when building localDict: \(d.id.uuidString)")
                }
            }
        }
        if localDupCount > 0 {
            print("[DishSync][warn] local duplicates encountered: \(localDupCount) (unique dup ids: \(localDupIdsLogged.count))")
        }

        // Build remoteDict safely (tolerate duplicate ids by overwriting, no crash)
        var remoteDict: [UUID: DishDECOD] = [:]
        var duplicateCount = 0
        var duplicateIdsLogged = Set<UUID>()
        for dish in uniqueRemoteDishes {
            guard let id = dish.id else { continue }
            if remoteDict.updateValue(dish, forKey: id) != nil {
                duplicateCount += 1
                if duplicateIdsLogged.insert(id).inserted {
                    print("[DishSync][dup] duplicate id encountered during merge: \(id.uuidString)")
                }
            }
        }
        if duplicateCount > 0 {
            print("[DishSync][warn] remote duplicates encountered during merge: \(duplicateCount) (unique dup ids: \(duplicateIdsLogged.count))")
        }

        var createdOrUpdated = 0
        for (id, remoteDish) in remoteDict {
            if let local = localDict[id] {
                local.updateFromDecoded(remoteDish)
                // если пришёл imageURL — очищаем base64, чтобы не было дублирования
                if remoteDish.imageURL != nil {
                    local.imageBase64 = nil
                }
            } else {
                context.insert(Dish(from: remoteDish))
            }
            createdOrUpdated += 1
        }

        // 3) Reconciliation: удалить локальные блюда, которых нет на сервере
        let remoteIds = Set(remoteDict.keys)
        var deletedLocal = 0
        for local in localDishes {
            // Удаляем только те, что относятся к текущему пользователю/его группам
            let isMine = (local.userId == userId) || (local.groupId != nil && userGroups.contains(local.groupId!))
            if isMine && !remoteIds.contains(local.id) {
                context.delete(local)
                deletedLocal += 1
            }
        }

        try context.save()
        print("[DishSync] upserted=\(createdOrUpdated), deletedLocal=\(deletedLocal)")

        // 4) Экспорт локальных блюд, которых нет на сервере (создать/обновить)
        try await exportLocalChangesToFirestoreAsync(userId: userId, groupIds: userGroups, context: context)
    }

    // MARK: - Import

    /// Получаем блюда текущего пользователя и все блюда его групп.
    func fetchAllAvailableDishes(userId: String, groupIds: [String]) async throws -> [DishDECOD] {
        var queries: [Query] = []
        // Блюда пользователя
        queries.append(db.collection("dishes").whereField("userId", isEqualTo: userId))
        // Блюда по каждой группе (Firestore не поддерживает OR с равенством и IN одновременно, поэтому отдельные запросы)
        for groupId in groupIds {
            queries.append(db.collection("dishes").whereField("groupId", isEqualTo: groupId))
        }

        var allDishes: [DishDECOD] = []
        for query in queries {
            let snapshot = try await query.getDocuments()
            let part: [DishDECOD] = snapshot.documents.compactMap { try? $0.data(as: DishDECOD.self) }
            allDishes.append(contentsOf: part)
        }

        // Return de-duplicated list by UUID
        let deduped = Self.removeDuplicates(allDishes)
        if deduped.count != allDishes.count {
            print("[DishSync][info] fetchAllAvailableDishes removed \(allDishes.count - deduped.count) duplicates (by id)")
        }
        return deduped
    }

    // MARK: - Export

    /// Экспортируем локальные блюда, которых нет на сервере (или у которых нет imageURL при наличии base64).
    func exportLocalChangesToFirestoreAsync(userId: String, groupIds: [String], context: ModelContext) async throws {
        let localDishes: [Dish] = try context.fetch(FetchDescriptor<Dish>())

        // Ориентируемся на актуальное состояние сервера
        let remote: [DishDECOD] = try await fetchAllAvailableDishes(userId: userId, groupIds: groupIds)
        let remoteIds = Set(remote.compactMap { $0.id })

        // Defensive: dedupe local dish ids to avoid redundant writes
        var seenLocal = Set<UUID>()
        var exported = 0
        for dish in localDishes {
            guard seenLocal.insert(dish.id).inserted else {
                print("[DishSync][dup-local] duplicate local id encountered: \(dish.id.uuidString)")
                continue
            }

            let isMine = (dish.userId == userId) || (dish.groupId != nil && groupIds.contains(dish.groupId!))
            guard isMine else { continue }

            let docId = dish.id.uuidString

            // Правила экспорта:
            // - если блюда нет на сервере -> создать
            // - если есть base64, а url нет -> загрузить в Storage, обновить Firestore
            // - если есть url (и опционально base64) -> обеспечить, что Firestore актуален
            if !remoteIds.contains(dish.id) {
                try await setDishInFirestoreAsync(dish: dish, docId: docId)
                exported += 1
            } else if dish.imageURL == nil, dish.imageBase64 != nil {
                // Сервер знает о блюде, но локально есть новое изображение в base64 -> заливаем
                try await setDishInFirestoreAsync(dish: dish, docId: docId)
                exported += 1
            }
        }

        print("[DishSync] exported=\(exported)")
    }

    // MARK: - Firestore write + Storage upload

    private func setDishInFirestoreAsync(dish: Dish, docId: String) async throws {
        // 1) Картинка
        let imageURL = try await uploadImageIfNeeded(dish: dish, docId: docId)

        // 2) Payload
        var payload: [String: Any] = [
            "id": docId,
            "name": dish.name,
            "about": dish.about,
            "category": dish.category?.rawValue ?? "",
            "userId": dish.userId ?? Auth.auth().currentUser?.uid ?? "",
            "groupId": dish.groupId ?? ""
        ]
        if let imageURL, !imageURL.isEmpty {
            payload["imageURL"] = imageURL
        }

        // 3) Запись Firestore
        try await db.collection("dishes").document(docId).setData(payload, merge: true)

        // 4) Локально: если мы только что загрузили картинку и получили URL — сохраняем его и очищаем base64
        if dish.imageURL == nil, let imageURL {
            dish.imageURL = imageURL
            dish.imageBase64 = nil
        }
    }

    /// Загружает изображение в Storage, если локально есть base64 и нет валидного imageURL.
    /// Возвращает URL или nil, если загружать не нужно.
    private func uploadImageIfNeeded(dish: Dish, docId: String) async throws -> String? {
        // Если уже есть валидный URL — ничего не делаем
        if let url = dish.imageURL, !url.isEmpty {
            return url
        }
        // Если нет base64 — нечего загружать
        guard let base64 = dish.imageBase64, var data = Data(base64Encoded: base64) else {
            return dish.imageURL
        }

        // Сжимаем/ресайзим
        data = ImageTools.resizedJPEGData(from: data, maxDimension: 1280, quality: 0.7) ?? data

        let ref = Storage.storage().reference(withPath: "dishes/\(docId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // putData -> downloadURL
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - Helpers

    func addOrUpdateDish(_ decoded: DishDECOD, context: ModelContext) async throws {
        if let id = decoded.id,
           let localDish = try? context.fetch(FetchDescriptor<Dish>(predicate: #Predicate { $0.id == id })).first {
            localDish.updateFromDecoded(decoded)
        } else {
            context.insert(Dish(from: decoded))
        }
        try? context.save()

        let docId = decoded.id?.uuidString ?? UUID().uuidString
        // Здесь мы пересоздаём Dish из decoded, чтобы отправить на сервер.
        // Если хотите избежать двойной конверсии — передавайте уже существующий Dish.
        try await setDishInFirestoreAsync(dish: Dish(from: decoded), docId: docId)
    }

    /// Мягкое удаление блюда из Firestore; удаление изображения в Storage — опционально и “мягко”.
    func deleteDishFromFirestore(_ dish: Dish) async throws {
        let dishId = dish.id.uuidString
        try await db.collection("dishes").document(dishId).delete()

        // Если хотите удалять картинку из Storage — делайте это мягко (игнорируйте 404)
        let ref = Storage.storage().reference(withPath: "dishes/\(dishId).jpg")
        do {
            try await ref.delete()
        } catch {
            // Игнорируем 404 Not Found
            let nsError = error as NSError
            if nsError.domain == StorageErrorDomain,
               StorageErrorCode(rawValue: nsError.code) == .objectNotFound {
                print("[DishSync] image not found in Storage for \(dishId), ignore")
            } else {
                print("[DishSync] Storage delete error for \(dishId): \(error.localizedDescription)")
            }
        }
    }

    static func removeDuplicates(_ dishes: [DishDECOD]) -> [DishDECOD] {
        var seen = Set<UUID>()
        var unique: [DishDECOD] = []
        var duplicatesLogged = Set<UUID>()
        for d in dishes {
            guard let id = d.id else { continue }
            if seen.insert(id).inserted {
                unique.append(d)
            } else if duplicatesLogged.insert(id).inserted {
                print("[DishSync][dup] removeDuplicates saw duplicate id: \(id.uuidString)")
            }
        }
        return unique
    }
}

// MARK: - ImageTools

enum ImageTools {
    static func resizedJPEGData(from data: Data, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let maxSide = max(size.width, size.height)
        let scale = maxSide > maxDimension ? maxDimension / maxSide : 1
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
