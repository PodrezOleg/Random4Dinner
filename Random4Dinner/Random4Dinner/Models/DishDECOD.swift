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
    let id: UUID?
    let name: String?
    let about: String?
    let imageBase64: String?
    let category: MealCategory?
    var userId: String?
    var groupId: String?
    
    struct DishesContainer: Codable {
        let dishes: [DishDECOD]
    }

    // 👇 Обновлённый инициализатор с обработкой старых JSON без категории
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try? container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.about = try container.decode(String.self, forKey: .about)
        self.imageBase64 = try? container.decode(String.self, forKey: .imageBase64)
        self.category = (try? container.decode(MealCategory.self, forKey: .category)) ?? .lunch
        self.userId = try? container.decode(String.self, forKey: .userId)
        self.groupId = try? container.decode(String.self, forKey: .groupId)
    }

    // 👇 Добавим init для ручного создания (не изменился)
    init(id: UUID = UUID(),
         name: String,
         about: String,
         imageBase64: String?,
         category: MealCategory,
         userId: String? = nil,
         groupId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.about = about
        self.imageBase64 = imageBase64
        self.category = category
        self.userId = userId
        self.groupId = groupId
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, about, imageBase64, category, userId, groupId
    }
}
