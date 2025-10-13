//
//  DishDECOD.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.03.25.
//

import Foundation
import SwiftData

// Простая структура для декодирования JSON
struct DishDECOD: Codable, Identifiable {
    var id: UUID?
    let name: String?
    let about: String?
    let imageBase64: String?   // старый формат
    let imageURL: String?      // ✅ новый формат (Storage)
    let category: MealCategory?
    var userId: String?
    var groupId: String?

    struct DishesContainer: Codable {
        let dishes: [DishDECOD]
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? c.decode(UUID.self, forKey: .id)
        self.name = try? c.decode(String.self, forKey: .name)
        self.about = try? c.decode(String.self, forKey: .about)
        self.imageURL = try? c.decode(String.self, forKey: .imageURL)          // ✅
        self.imageBase64 = try? c.decode(String.self, forKey: .imageBase64)    // fallback
        self.category = (try? c.decode(MealCategory.self, forKey: .category)) ?? .lunch
        self.userId = try? c.decode(String.self, forKey: .userId)
        self.groupId = try? c.decode(String.self, forKey: .groupId)
    }

    init(id: UUID = UUID(),
         name: String,
         about: String,
         imageBase64: String? = nil,
         imageURL: String? = nil,                 // ✅
         category: MealCategory,
         userId: String? = nil,
         groupId: String? = nil) {
        self.id = id
        self.name = name
        self.about = about
        self.imageBase64 = imageBase64
        self.imageURL = imageURL                  // ✅
        self.category = category
        self.userId = userId
        self.groupId = groupId
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, about, imageBase64, imageURL, category, userId, groupId
    }
}
