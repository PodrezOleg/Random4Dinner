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

    /// Основная функция синхронизации: импорт блюд пользователя + групповых блюд
    func syncDishes(context: ModelContext, userGroups: [String]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Нет авторизации"])
        }

        // 1. Импортируем блюда пользователя и групп, где он состоит
        let remoteDishes = try await fetchAllAvailableDishes(userId: userId, groupIds: userGroups)
        // --- Вот тут фильтруем дубликаты ---
        let uniqueRemoteDishes = Self.removeDuplicates(remoteDishes)

        // 2. Обновляем локальную базу
        let localDishes = try context.fetch(FetchDescriptor<Dish>())
        let localDict = Dictionary(uniqueKeysWithValues: localDishes.map { ($0.id, $0) })
        let remoteDict = Dictionary(uniqueKeysWithValues: uniqueRemoteDishes.compactMap { dish in dish.id.map { ($0, dish) } })

        for (id, remoteDish) in remoteDict {
            if let local = localDict[id] {
                local.updateFromDecoded(remoteDish)
            } else {
                context.insert(Dish(from: remoteDish))
            }
        }
        try context.save()

        // 3. Экспортируем новые/изменённые блюда (только личные и групповые пользователя)
        try await exportLocalChangesToFirestoreAsync(userId: userId, groupIds: userGroups, context: context)
    }

    /// Импорт блюд пользователя и групп
    func fetchAllAvailableDishes(userId: String, groupIds: [String]) async throws -> [DishDECOD] {
        return try await withCheckedThrowingContinuation { continuation in
            var queries: [Query] = []
            // Личные блюда пользователя
            queries.append(db.collection("dishes").whereField("userId", isEqualTo: userId))
            // Групповые блюда
            for groupId in groupIds {
                queries.append(db.collection("dishes").whereField("groupId", isEqualTo: groupId))
            }

            var allDishes: [DishDECOD] = []
            let group = DispatchGroup()

            for query in queries {
                group.enter()
                query.getDocuments { snapshot, error in
                    defer { group.leave() }
                    if let docs = snapshot?.documents {
                        allDishes.append(contentsOf: docs.compactMap { try? $0.data(as: DishDECOD.self) })
                    }
                }
            }

            group.notify(queue: .main) {
                continuation.resume(returning: Self.removeDuplicates(allDishes))
            }
        }
    }

    /// Экспорт только тех блюд, которыми владеет пользователь (userId) или его группа
    func exportLocalChangesToFirestoreAsync(userId: String, groupIds: [String], context: ModelContext) async throws {
        let localDishes = try context.fetch(FetchDescriptor<Dish>())
        // Получаем id всех блюд пользователя и его групп из Firestore
        let remote: [DishDECOD] = try await fetchAllAvailableDishes(userId: userId, groupIds: groupIds)
        let remoteIds = Set(remote.compactMap { $0.id })
        var exported = 0

        for dish in localDishes {
            let isMine = (dish.userId == userId) || (dish.groupId != nil && groupIds.contains(dish.groupId!))
            if !remoteIds.contains(dish.id) && isMine {
                let docId = dish.id.uuidString
                try await setDishInFirestoreAsync(dish: dish, docId: docId)
                exported += 1
            }
        }
        print("✅ Экспортировано новых блюд в Firestore: \(exported)")
    }

    /// Асинхронная запись одного блюда в Firestore
    private func setDishInFirestoreAsync(dish: Dish, docId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.collection("dishes").document(docId).setData([
                "id": docId,
                "name": dish.name,
                "about": dish.about,
                "imageBase64": dish.imageBase64 ?? "",
                "category": dish.category?.rawValue ?? "",
                "userId": dish.userId ?? Auth.auth().currentUser?.uid ?? "",
                "groupId": dish.groupId ?? ""
            ], merge: true) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func addOrUpdateDish(_ decoded: DishDECOD, context: ModelContext) async throws {
        let docId = decoded.id?.uuidString ?? UUID().uuidString
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.collection("dishes").document(docId).setData([
                "id": docId,
                "name": decoded.name ?? "",
                "about": decoded.about ?? "",
                "imageBase64": decoded.imageBase64 ?? "",
                "category": decoded.category?.rawValue ?? "",
                "userId": decoded.userId ?? Auth.auth().currentUser?.uid ?? "",
                "groupId": decoded.groupId ?? ""
            ], merge: true) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        // Сохраняем локально
        if let id = decoded.id,
           let localDish = try? context.fetch(FetchDescriptor<Dish>(predicate: #Predicate { $0.id == id })).first {
            localDish.updateFromDecoded(decoded)
        } else {
            context.insert(Dish(from: decoded))
        }
        try? context.save()
    }

    func deleteDishFromFirestore(_ dish: Dish) async throws {
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
