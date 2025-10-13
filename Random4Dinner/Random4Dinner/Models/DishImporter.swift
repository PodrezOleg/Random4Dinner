//
//  DishImporter.swift
//  Random4Dinner
//
//  Created by Oleg Podрез on 30.03.25.
//

import Foundation
import SwiftData
import SwiftUI
import FirebaseAuth

// Импорт одного блюда (можно оставить как private)
@MainActor
private func importDish(from decod: DishDECOD, context: ModelContext) {
    let dish = Dish(
        id: decod.id ?? UUID(),
        name: decod.name ?? "",
        about: decod.about ?? "",
        imageBase64: decod.imageBase64,
        imageURL: decod.imageURL,
        category: decod.category,
        userId: decod.userId,
        groupId: decod.groupId
    )
    context.insert(dish)
}

// Импорт всех блюд из JSON с опорой на выбранную группу и моментальной отправкой в Firestore
@MainActor
func importDishesFromJSON(context: ModelContext, selectedGroupId: String?) async {
    guard let url = Bundle.main.url(forResource: "dishes", withExtension: "json") else {
        print("Не найден файл dishes.json в бандле!")
        return
    }
    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let container = try decoder.decode(DishDECOD.DishesContainer.self, from: data)
        print("Загружено блюд: \(container.dishes.count)")

        guard let userId = Auth.auth().currentUser?.uid else {
            // Если нет авторизованного пользователя — импортируем как личные оффлайн
            for dish in container.dishes {
                var dishWithUser = dish
                dishWithUser.userId = nil
                dishWithUser.groupId = nil
                importDish(from: dishWithUser, context: context)
            }
            try? context.save()
            return
        }

        // Импортируем: если есть выбранная группа — в неё; иначе как личные
        for dish in container.dishes {
            let resolvedId = dish.id ?? UUID()

            // Подготавливаем неизменяемые значения заранее, чтобы не захватывать var
            let name = dish.name ?? ""
            let about = dish.about ?? ""
            let imageBase64 = dish.imageBase64
            let imageURL = dish.imageURL
            let category = dish.category ?? .lunch
            let finalUserId: String? = userId
            let finalGroupId: String? = selectedGroupId // nil -> личные; id -> групповые

            // 1) Локально вставляем (мы уже на MainActor)
            let localDecod = DishDECOD(
                id: resolvedId,
                name: name,
                about: about,
                imageBase64: imageBase64,
                imageURL: imageURL,
                category: category,
                userId: finalUserId,
                groupId: finalGroupId
            )
            importDish(from: localDecod, context: context)

            // 2) Отправляем в Firestore (DishSyncService — @MainActor)
            do {
                let syncDecod = DishDECOD(
                    id: resolvedId,
                    name: name,
                    about: about,
                    imageBase64: imageBase64,
                    imageURL: imageURL,
                    category: category,
                    userId: finalUserId,
                    groupId: finalGroupId
                )
                try await DishSyncService.shared.addOrUpdateDish(syncDecod, context: context)
            } catch {
                // Не блокируем импорт, но логируем и показываем мягкое уведомление
                NotificationCenterService.shared.showWarning(
                    "Не удалось синхронизировать блюдо \(name)"
                )
                print("Ошибка синхронизации блюда \(name): \(error)")
            }
        }

        // Финальное сохранение локальной базы
        try? context.save()
    } catch {
        print("Ошибка импорта блюд: \(error)")
    }
}
