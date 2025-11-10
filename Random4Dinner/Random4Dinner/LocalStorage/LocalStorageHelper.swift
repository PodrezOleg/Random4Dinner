//
//  LocalStorageHelper.swift
//  Random4Dinner
//
//  Created by Oleg Podрез on 11.05.25.
//

import Foundation

enum LocalStorageHelper {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Group-aware path
    static func dishesJSONURL(for userId: String, groupId: String?) -> URL {
        if let gid = groupId, !gid.isEmpty {
            return documentsDirectory.appendingPathComponent("dishes_user_\(userId)_group_\(gid).json")
        } else {
            return documentsDirectory.appendingPathComponent("dishes_user_\(userId).json")
        }
    }

    // Backward-compat convenience
    static func dishesJSONURL(for userId: String) -> URL {
        dishesJSONURL(for: userId, groupId: nil)
    }
    
    static var imagesDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("images")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    static func saveImage(data: Data, for dishID: UUID) throws -> String {
        let imageURL = imagesDirectory.appendingPathComponent("\(dishID).jpg")
        try data.write(to: imageURL)
        return imageURL.absoluteString
    }
    
    static func loadImage(for dishID: UUID) -> Data? {
        let imageURL = imagesDirectory.appendingPathComponent("\(dishID).jpg")
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return nil }
        return try? Data(contentsOf: imageURL)
    }
    
    static func deleteImage(for dishID: UUID) {
        let imageURL = imagesDirectory.appendingPathComponent("\(dishID).jpg")
        if FileManager.default.fileExists(atPath: imageURL.path) {
            try? FileManager.default.removeItem(at: imageURL)
        }
    }
    
    // --- Работа с блюдами ---
    
    // Save dishes (user or user+group)
    static func saveDishes<T: Codable>(_ dishes: [T], for userId: String, groupId: String?) throws {
        let url = dishesJSONURL(for: userId, groupId: groupId)
        let data = try JSONEncoder().encode(dishes)
        try data.write(to: url, options: .atomic)
    }

    // Backward-compat
    static func saveDishes<T: Codable>(_ dishes: [T], for userId: String) throws {
        try saveDishes(dishes, for: userId, groupId: nil)
    }

    // Load dishes (user or user+group)
    static func loadDishes<T: Codable>(for userId: String, groupId: String?, as type: T.Type) -> [T] {
        let url = dishesJSONURL(for: userId, groupId: groupId)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }

    // Backward-compat
    static func loadDishes<T: Codable>(for userId: String, as type: T.Type) -> [T] {
        loadDishes(for: userId, groupId: nil, as: type)
    }

    // Delete dishes (user or user+group)
    static func deleteDishes(for userId: String, groupId: String?) throws {
        let url = dishesJSONURL(for: userId, groupId: groupId)
        try FileManager.default.removeItem(at: url)
    }

    // Backward-compat
    static func deleteDishes(for userId: String) throws {
        try deleteDishes(for: userId, groupId: nil)
    }
    
    // Save user's (or selected group's) dishes to local JSON
    static func saveDishesForUser(userId: String, groupId: String? = nil) {
        Task {
            do {
                let groupIds = groupId.map { [$0] } ?? []
                let dishes = try await DishSyncService.shared.fetchAllAvailableDishes(userId: userId, groupIds: groupIds)
                try saveDishes(dishes, for: userId, groupId: groupId)
            } catch {
                print("Не удалось сохранить блюда локально: \(error)")
            }
        }
    }
}
