//
//  DishImporter.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.03.25.
//

import Foundation
import SwiftData
import SwiftUI
import FirebaseAuth


// Импорт одного блюда (можно оставить как private)
func importDish(from decod: DishDECOD, context: ModelContext) {
    let dish = Dish(
        name: decod.name ?? "",
        about: decod.about ?? "",
        imageBase64: decod.imageBase64,
        imageURL: decod.imageURL,            // ✅
        category: decod.category,
        userId: decod.userId,
        groupId: decod.groupId
    )
    context.insert(dish)
}

// Импорт всех блюд из JSON
func importDishesFromJSON(context: ModelContext) {
    guard let url = Bundle.main.url(forResource: "dishes", withExtension: "json") else {
        print("Не найден файл dishes.json в бандле!")
        return
    }
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let container = try decoder.decode(DishDECOD.DishesContainer.self, from: data)
        print("Загружено блюд: \(container.dishes.count)")
        let userId = Auth.auth().currentUser?.uid // 👈 получаем id пользователя
        for dish in container.dishes {
            // Задаём userId, чтобы блюдо стало "личным"
            var dishWithUser = dish
            dishWithUser.userId = userId
            dishWithUser.groupId = nil
            importDish(from: dishWithUser, context: context)
        }
        try? context.save()
    } catch {
        print("Ошибка импорта блюд: \(error)")
    }
}

