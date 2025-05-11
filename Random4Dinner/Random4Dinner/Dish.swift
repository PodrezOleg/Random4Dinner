//
//  Dish.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import Foundation
import SwiftData

@Model
class Dish {
    var id: UUID
    var name: String
    var about: String
    var imageBase64: String?
    var category: MealCategory?

    init(
        id: UUID = UUID(),
        name: String,
        about: String,
        imageBase64: String,
        category: MealCategory?
    ) {
        self.id = id
        self.name = name
        self.about = about
        self.imageBase64 = imageBase64
        self.category = category
    }

    convenience init(from decoded: DishDECOD) {
        self.init(
            id: decoded.id ?? UUID(),
            name: decoded.name ?? "Без названия",
            about: decoded.about ?? "Нет описания",
            imageBase64: decoded.imageBase64 ?? "",
            category: decoded.category
        )
    }

    func updateFromDecoded(_ decoded: DishDECOD) {
        self.name = decoded.name ?? self.name
        self.about = decoded.about ?? self.about
        self.imageBase64 = decoded.imageBase64 ?? self.imageBase64
        self.category = decoded.category
    }
}
