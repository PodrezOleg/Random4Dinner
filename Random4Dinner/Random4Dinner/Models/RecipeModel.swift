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
    case soup = "Cуп"
    case other = "Другое"
    var id: String { rawValue }
}

struct Ingredient: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var amount: Double   // количество (например, граммы)
    var unit: String     // единица измерения (г, шт, мл и т.д.)

    init(name: String, amount: Double, unit: String) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.unit = unit
    }
}

@Model
class Recipe {
    var id: UUID
    var title: String
    var recipeDescription: String
    var category: RecipeCategory
    var url: String?
    var createdAt: Date

    var ingredients: [Ingredient]
    var servings: Int // сколько порций рассчитано

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
