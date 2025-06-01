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
    var userId: String?
    var groupId: String?

    init(
        id: UUID = UUID(),
        name: String,
        about: String,
        imageBase64: String?,
        category: MealCategory?,
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

    convenience init(from decoded: DishDECOD) {
        self.init(
            id: decoded.id ?? UUID(),
            name: decoded.name ?? "Без названия",
            about: decoded.about ?? "Нет описания",
            imageBase64: decoded.imageBase64 ?? "",
            category: decoded.category,
            userId: decoded.userId,    // 👈
            groupId: decoded.groupId   // 👈
        )
    }

    func updateFromDecoded(_ decoded: DishDECOD) {
        self.name = decoded.name ?? self.name
        self.about = decoded.about ?? self.about
        self.imageBase64 = decoded.imageBase64 ?? self.imageBase64
        self.category = decoded.category
        self.userId = decoded.userId ?? self.userId
        self.groupId = decoded.groupId ?? self.groupId
    }
}
