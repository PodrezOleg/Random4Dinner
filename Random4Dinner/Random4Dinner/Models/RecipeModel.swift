//
//  RecipeModel.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.05.25.
//

import Foundation
import SwiftData

enum RecipeCategory: String, CaseIterable, Identifiable, Codable {
    case dessert = "Десерт"
    case pie = "Пирог"
    case meat = "Мясо"
    case bread = "Хлеб"
    case drink = "Напитки"
    case soup = "Суп"
    case other = "Другое"
    var id: String { rawValue }
}

struct Ingredient: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var unit: String
}

@Model
class Recipe: Identifiable {
    var id: UUID
    var title: String
    var recipeDescription: String
    var category: RecipeCategory
    var url: String?
    var createdAt: Date
    var ingredients: [Ingredient]
    var servings: Int
    var userId: String?  // ID пользователя, создавшего рецепт
    var isSync: Bool = false  // Флаг синхронизации с Firebase
    var lastModified: Date?

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: RecipeCategory,
        url: String? = nil,
        createdAt: Date = Date(),
        ingredients: [Ingredient] = [],
        servings: Int = 1,
        userId: String? = nil,
        isSync: Bool = false,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.recipeDescription = description
        self.category = category
        self.url = url
        self.createdAt = createdAt
        self.ingredients = ingredients
        self.servings = servings
        self.userId = userId
        self.isSync = isSync
        self.lastModified = lastModified
    }
}

// Расширение для конвертации в словарь для Firebase
extension Recipe {
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "title": title,
            "description": recipeDescription,
            "category": category.rawValue,
            "url": url as Any,
            "createdAt": createdAt.timeIntervalSince1970,
            "ingredients": ingredients.map { [
                "id": $0.id.uuidString,
                "name": $0.name,
                "amount": $0.amount,
                "unit": $0.unit
            ]},
            "servings": servings,
            "userId": userId as Any,
            "lastModified": (lastModified ?? createdAt).timeIntervalSince1970 // ✅
        ]
    }
}
