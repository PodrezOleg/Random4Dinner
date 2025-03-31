//
//  DishSyncService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 31.03.25.
//

import Foundation
import SwiftData

enum DishSyncError: Error {
    case exportFailed(Error)
    case importFailed(Error)
}

class DishSyncService {
    
    static let shared = DishSyncService()
    private init() {}

    func importInitialDishesIfNeeded(context: ModelContext) async {
        let alreadyImported = UserDefaults.standard.bool(forKey: "didImportInitialDishes")
        guard !alreadyImported else { return }

        do {
            let decodedDishes = try await APIService.shared.fetchDishes()
            let existing = try context.fetch(FetchDescriptor<Dish>())
            let existingNames = Set(existing.map { $0.name })

            for dish in decodedDishes {
                if !existingNames.contains(dish.name) {
                    let newDish = Dish(name: dish.name, about: dish.about, imageBase64: dish.imageBase64)
                    context.insert(newDish)
                }
            }
            try context.save()
            UserDefaults.standard.set(true, forKey: "didImportInitialDishes")
        } catch {
            print("❌ Ошибка импорта: \(error)")
        }
    }

    func exportDishesToJSON(context: ModelContext) {
        do {
            let dishes = try context.fetch(FetchDescriptor<Dish>())
            let encodedDishes = dishes.map {
                DishDECOD(name: $0.name, about: $0.about, imageBase64: $0.imageBase64)
            }
            let container = DishesContainer(dishes: encodedDishes)
            let jsonData = try JSONEncoder().encode(container)

            let url = getDocumentsDirectory().appendingPathComponent("dishes.json")
            try jsonData.write(to: url)

            print("✅ Данные экспортированы в JSON: \(url)")
        } catch {
            print("❌ Ошибка экспорта: \(error)")
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
