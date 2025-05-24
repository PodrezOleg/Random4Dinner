//
//  DishSyncService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 31.03.25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData

final class DishSyncService {
    static let shared = DishSyncService()
    private let db = Firestore.firestore()
    private init() {}

    /// Основная функция синхронизации: импорт из Firestore + экспорт новых/изменённых локальных блюд обратно в Firestore
    func syncDishes(context: ModelContext) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Нет авторизации"])
        }

        // 1. Импорт из Firestore (fetch)
        let remoteDishes = try await fetchDishesFromFirestoreAsync(userId: userId)

        // 2. Импортируем новые блюда из Firestore (если их нет локально или если обновлены)
        let localDishes = try context.fetch(FetchDescriptor<Dish>())
        let localDict = Dictionary(uniqueKeysWithValues: localDishes.map { ($0.id, $0) })
        let remoteDict = Dictionary(uniqueKeysWithValues: remoteDishes.compactMap { dish in dish.id.map { ($0, dish) } })

        for (id, remoteDish) in remoteDict {
            if let local = localDict[id] {
                // Можно добавить сравнение времени/контента для обновления, если нужно
                local.updateFromDecoded(remoteDish)
            } else {
                context.insert(Dish(from: remoteDish))
            }
        }
        try context.save()

        // 3. Экспортируем новые/изменённые блюда в Firestore
        try await exportLocalChangesToFirestoreAsync(userId: userId, context: context)
    }

    // MARK: - Firestore async helpers

    /// Получить блюда пользователя из Firestore (async)
    func fetchDishesFromFirestoreAsync(userId: String) async throws -> [DishDECOD] {
        try await withCheckedThrowingContinuation { continuation in
            db.collection("dishes").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let dishes: [DishDECOD] = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: DishDECOD.self)
                    } ?? []
                    continuation.resume(returning: Self.removeDuplicates(dishes))
                }
            }
        }
    }

    /// Экспорт только локальных блюд, которых нет в Firestore (или которые отличаются) (async)
    func exportLocalChangesToFirestoreAsync(userId: String, context: ModelContext) async throws {
        let localDishes = try context.fetch(FetchDescriptor<Dish>())

        // Получаем id блюд в Firestore
        let remote: [DishDECOD] = try await withCheckedThrowingContinuation { continuation in
            db.collection("dishes").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let arr: [DishDECOD] = snapshot?.documents.compactMap { try? $0.data(as: DishDECOD.self) } ?? []
                    continuation.resume(returning: arr)
                }
            }
        }
        let remoteIds = Set(remote.compactMap { $0.id })
        var exported = 0

        // Экспортируем блюда, которых нет в Firestore
        for dish in localDishes {
            if !remoteIds.contains(dish.id) {
                let docId = dish.id.uuidString
                try await setDishInFirestoreAsync(dish: dish, userId: userId, docId: docId)
                exported += 1
            }
        }
        print("✅ Экспортировано новых блюд в Firestore: \(exported)")
    }

    /// Асинхронная запись одного блюда в Firestore
    private func setDishInFirestoreAsync(dish: Dish, userId: String, docId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.collection("dishes").document(docId).setData([
                "id": docId,
                "name": dish.name,
                "about": dish.about,
                "imageBase64": dish.imageBase64 ?? "",
                "category": dish.category?.rawValue ?? "",
                "userId": userId
            ], merge: true) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Добавить или обновить блюдо и в Firestore, и локально (SwiftData)
    func addOrUpdateDish(_ decoded: DishDECOD, context: ModelContext) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Нет авторизации"])
        }
        let docId = decoded.id?.uuidString ?? UUID().uuidString
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.collection("dishes").document(docId).setData([
                "id": docId,
                "name": decoded.name ?? "",
                "about": decoded.about ?? "",
                "imageBase64": decoded.imageBase64 ?? "",
                "category": decoded.category?.rawValue ?? "",
                "userId": userId
            ], merge: true) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        // Сохраняем локально (обновляем или добавляем)
        if let id = decoded.id,
           let localDish = try? context.fetch(FetchDescriptor<Dish>(predicate: #Predicate { $0.id == id })).first {
            localDish.updateFromDecoded(decoded)
        } else {
            context.insert(Dish(from: decoded))
        }
        try? context.save()
    }

    func deleteDishFromFirestore(_ dish: Dish) async throws {
        guard let _ = Auth.auth().currentUser?.uid else { return }
        let dishId = dish.id.uuidString
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.collection("dishes").document(dishId).delete { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // Быстрое удаление дублей по id
    static func removeDuplicates(_ dishes: [DishDECOD]) -> [DishDECOD] {
        var seen = Set<UUID>()
        var unique: [DishDECOD] = []
        for d in dishes {
            if let id = d.id, seen.insert(id).inserted {
                unique.append(d)
            }
        }
        return unique
    }
}
