//
//  LocalStorageHelper.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.05.25.
//

import Foundation
import FirebaseCore

enum LocalStorageHelper {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Путь для блюд конкретного пользователя
    static func dishesJSONURL(for userId: String) -> URL {
        documentsDirectory.appendingPathComponent("dishes_\(userId).json")
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
        return "images/\(dishID).jpg"
    }
    
    static func loadImage(for dishID: UUID) -> Data? {
        let imageURL = imagesDirectory.appendingPathComponent("\(dishID).jpg")
        return try? Data(contentsOf: imageURL)
    }
    
    static func deleteImage(for dishID: UUID) {
        let imageURL = imagesDirectory.appendingPathComponent("\(dishID).jpg")
        try? FileManager.default.removeItem(at: imageURL)
    }
    
    // --- Работа с блюдами ---
    
    // Сохранить блюда пользователя (или группы)
    static func saveDishes<T: Codable>(_ dishes: [T], for userId: String) throws {
        let url = dishesJSONURL(for: userId)
        let data = try JSONEncoder().encode(dishes)
        try data.write(to: url, options: .atomic)
    }
    
    // Загрузить блюда пользователя (или группы)
    static func loadDishes<T: Codable>(for userId: String, as type: T.Type) -> [T] {
        let url = dishesJSONURL(for: userId)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }
    
    // Удалить блюда пользователя
    static func deleteDishes(for userId: String) throws {
        let url = dishesJSONURL(for: userId)
        try FileManager.default.removeItem(at: url)
    }
    
    // Сохраняет блюда пользователя локально (примерная реализация)
    static func saveDishesForUser(userId: String) {
        // Получить блюда пользователя из Firestore или памяти
        // (пример: получите из FirestoreService или передайте сюда массив блюд)
        GroupFirestoreService.shared.getDishesForUser(userId: userId) { result in
            switch result {
            case .success(let dishes):
                do {
                    try saveDishes(dishes, for: userId)
                } catch {
                    print("Не удалось сохранить блюда локально: \(error)")
                }
            case .failure(let error):
                print("Ошибка при получении блюд для пользователя: \(error)")
            }
        }
    }
}
