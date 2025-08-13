//
//  DishSyncService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 31.03.25.
//

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
import UIKit
import FirebaseStorage

final class DishSyncService {
    static let shared = DishSyncService()
    private let db = Firestore.firestore()
    private init() {}

    func syncDishes(context: ModelContext, userGroups: [String]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Нет авторизации"])
        }

        let remoteDishes = try await fetchAllAvailableDishes(userId: userId, groupIds: userGroups)
        let uniqueRemoteDishes = Self.removeDuplicates(remoteDishes)

        try await MainActor.run {
            let localDishes = try context.fetch(FetchDescriptor<Dish>())
            let localDict = Dictionary(uniqueKeysWithValues: localDishes.map { ($0.id, $0) })
            let remoteDict = Dictionary(uniqueKeysWithValues: uniqueRemoteDishes.compactMap { dish in dish.id.map { ($0, dish) } })

            for (id, remoteDish) in remoteDict {
                if let local = localDict[id] {
                    local.updateFromDecoded(remoteDish)
                    if remoteDish.imageURL != nil {
                        local.imageBase64 = nil
                    }
                } else {
                    context.insert(Dish(from: remoteDish))
                }
            }
            try context.save()
        }

        try await exportLocalChangesToFirestoreAsync(userId: userId, groupIds: userGroups, context: context)
    }

    private func uploadImageIfNeeded(dish: Dish, docId: String) async throws -> String? {
        if dish.imageBase64 == nil, let url = dish.imageURL, !url.isEmpty { return url }

        guard let base64 = dish.imageBase64,
              var data = Data(base64Encoded: base64) else { return dish.imageURL }

        data = ImageTools.resizedJPEGData(from: data, maxDimension: 1280, quality: 0.7) ?? data

        let ref = Storage.storage().reference(withPath: "dishes/\(docId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func fetchAllAvailableDishes(userId: String, groupIds: [String]) async throws -> [DishDECOD] {
        return try await withCheckedThrowingContinuation { continuation in
            var queries: [Query] = []
            queries.append(db.collection("dishes").whereField("userId", isEqualTo: userId))
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

    func exportLocalChangesToFirestoreAsync(userId: String, groupIds: [String], context: ModelContext) async throws {
        let localDishes: [Dish] = try await MainActor.run {
            try context.fetch(FetchDescriptor<Dish>())
        }

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

    private func setDishInFirestoreAsync(dish: Dish, docId: String) async throws {
        let imageURL = try await uploadImageIfNeeded(dish: dish, docId: docId)
        
        var payload: [String: Any] = [
            "id": docId,
            "name": dish.name,
            "about": dish.about,
            "category": dish.category?.rawValue ?? "",
            "userId": dish.userId ?? Auth.auth().currentUser?.uid ?? "",
            "groupId": dish.groupId ?? ""
        ]
        if let imageURL { payload["imageURL"] = imageURL }
        
        try await db.collection("dishes").document(docId).setData(payload, merge: true)
        
        let setImageURL = dish.imageURL == nil
        await MainActor.run {
            dish.imageBase64 = nil
            if setImageURL { dish.imageURL = imageURL }
        }
    }

    func addOrUpdateDish(_ decoded: DishDECOD, context: ModelContext) async throws {
        try await MainActor.run {
            if let id = decoded.id,
               let localDish = try? context.fetch(FetchDescriptor<Dish>(predicate: #Predicate { $0.id == id })).first {
                localDish.updateFromDecoded(decoded)
            } else {
                context.insert(Dish(from: decoded))
            }
            try? context.save()
        }

        let docId = decoded.id?.uuidString ?? UUID().uuidString
        try await setDishInFirestoreAsync(dish: Dish(from: decoded), docId: docId)
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
