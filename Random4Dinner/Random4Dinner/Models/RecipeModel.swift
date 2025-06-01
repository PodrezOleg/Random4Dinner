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

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: RecipeCategory,
        url: String? = nil,
        createdAt: Date = .now,
        ingredients: [Ingredient] = [],
        servings: Int = 1
    ) {
        self.id = id
        self.title = title
        self.recipeDescription = description
        self.category = category
        self.url = url
        self.createdAt = createdAt
        self.ingredients = ingredients
        self.servings = servings
    }
}
