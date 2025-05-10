//
//  Dish.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftData
import Foundation

@Model
class Dish {
    @Attribute(.unique)
    var id: UUID?
    var name: String
    var about: String
    var imageBase64: String?
    var category: MealCategory?

    init(name: String, about: String, imageBase64: String?, category: MealCategory) {
        self.id = UUID()
        self.name = name
        self.about = about
        self.imageBase64 = imageBase64
        self.category = category
    }

    // Конвертация из DishDECOD в Dish для хранения
    convenience init(from decoded: DishDECOD) {
        self.init(
            name: decoded.name,
            about: decoded.about,
            imageBase64: decoded.imageBase64,
            category: decoded.category
        )
    }
}
