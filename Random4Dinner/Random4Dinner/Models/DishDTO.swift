//
//  DishDTO.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 10.10.25.
//

import Foundation

struct DishDTO: Identifiable, Codable {
    var id: String
    var name: String
    var about: String
    var imageBase64: String?
    var imageURL: String?
    var category: String
    var userId: String?
    var groupId: String? // nil — гостевой

    init(
        id: String,
        name: String,
        about: String,
        imageBase64: String? = nil,
        imageURL: String? = nil,
        category: String,
        userId: String? = nil,
        groupId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.about = about
        self.imageBase64 = imageBase64
        self.imageURL = imageURL
        self.category = category
        self.userId = userId
        self.groupId = groupId
    }
}

// MARK: - Mapping: Dish (@Model) <-> DishDTO
extension DishDTO {
    init(from model: Dish) {
        self.id = model.id.uuidString
        self.name = model.name
        self.about = model.about
        self.imageBase64 = model.imageBase64
        self.imageURL = model.imageURL
        self.category = model.category?.rawValue ?? MealCategory.lunch.rawValue
        self.userId = model.userId
        self.groupId = model.groupId
    }

    func toModel() -> Dish {
        let uuid = UUID(uuidString: id) ?? UUID()
        return Dish(
            id: uuid,
            name: name,
            about: about,
            imageBase64: imageBase64,
            imageURL: imageURL,
            category: MealCategory(rawValue: category) ?? .lunch,
            userId: userId,
            groupId: groupId
        )
    }
}

// MARK: - Mapping: DishDECOD <-> DishDTO
extension DishDTO {
    init(from decoded: DishDECOD) {
        self.id = (decoded.id ?? UUID()).uuidString
        self.name = decoded.name ?? "Без названия"
        self.about = decoded.about ?? "Нет описания"
        self.imageBase64 = decoded.imageBase64
        self.imageURL = decoded.imageURL
        self.category = (decoded.category ?? .lunch).rawValue
        self.userId = decoded.userId
        self.groupId = decoded.groupId
    }

    func toDecoded() -> DishDECOD {
        let uuid = UUID(uuidString: id) ?? UUID()
        return DishDECOD(
            id: uuid,
            name: name,
            about: about,
            imageBase64: imageBase64,
            imageURL: imageURL,
            category: MealCategory(rawValue: category) ?? .lunch,
            userId: userId,
            groupId: groupId
        )
    }
}
