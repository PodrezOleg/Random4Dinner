//
//  DishSyncService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 31.03.25.
//

import Foundation
import SwiftData
import Network

enum DishSyncError: Error {
    case exportFailed(Error)
    case importFailed(Error)
}

class DishSyncService {

    static let shared = DishSyncService()

    private init() {
        startNetworkMonitor()
    }

    // MARK: - Публичный метод синхронизации с NAS
    func syncDishes(context: ModelContext) async {
        guard await isLocalNetworkReachable() else {
            print("🚫 Локальная сеть недоступна")
            return
        }

        do {
            let remoteDishes = try await APIService.shared.fetchDishes()
            print("📥 Загружено с NAS: \(remoteDishes.count) блюд")

            let localDishes = try context.fetch(FetchDescriptor<Dish>())
            var localDict = Dictionary(uniqueKeysWithValues: localDishes.compactMap { dish in
                dish.id.map { ($0, dish) }
            })

            let remoteDict = Dictionary(uniqueKeysWithValues: remoteDishes.compactMap { dish in
                dish.id.map { ($0, dish) }
            })

            var changesMade = false
            var updatedCount = 0
            var addedCount = 0
            var deletedCount = 0

            for (id, remoteDish) in remoteDict {
                if let localDish = localDict[id] {
                    if localDish.name != remoteDish.name ||
                        localDish.about != remoteDish.about ||
                        localDish.imageBase64 != remoteDish.imageBase64 ||
                        localDish.category != remoteDish.category {

                        localDish.name = remoteDish.name
                        localDish.about = remoteDish.about
                        localDish.imageBase64 = remoteDish.imageBase64
                        localDish.category = remoteDish.category
                        updatedCount += 1
                        changesMade = true
                    }
                    localDict.removeValue(forKey: id)
                } else {
                    context.insert(Dish(from: remoteDish))
                    addedCount += 1
                    changesMade = true
                }
            }

            for (_, dish) in localDict {
                context.delete(dish)
                deletedCount += 1
                changesMade = true
            }

            if changesMade {
                try context.save()
                let summary = "🔄 Обновлены: \(updatedCount), ➕ Добавлены: \(addedCount), ❌ Удалены: \(deletedCount)"
                NotificationCenterService.shared.showSuccess(summary)
                print("✅ Синхронизация завершена\n\(summary)")
            } else {
                print("⏩ Синхронизация: нет изменений")
                NotificationCenterService.shared.showSuccess("⏩ Нет изменений, данные актуальны")
            }
        } catch {
            print("❌ Ошибка синхронизации: \(error)")
            NotificationCenterService.shared.showError(
                "Не удалось синхронизировать блюда с NAS",
                resolution: "Проверьте подключение к сети NAS или повторите позже"
            )
        }
    }

    // MARK: - Импорт из локального файла JSON
    func importDishesFromLocalJSON(context: ModelContext) {
        let url = getDocumentsDirectory().appendingPathComponent("dishes.json")
        guard let data = try? Data(contentsOf: url) else { return }

        do {
            let container = try JSONDecoder().decode(DishesContainer.self, from: data)
            for dish in container.dishes {
                if let existing = try? context.fetch(FetchDescriptor<Dish>()).first(where: { $0.id == dish.id }) {
                    existing.update(from: dish)
                } else {
                    context.insert(Dish(from: dish))
                }
            }
            try context.save()
            print("📦 Импорт из локального JSON завершён")

            // ⏱️ Запускаем sync через 5 секунд
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                NotificationCenterService.shared.showInfo("Попытка синхронизации с NAS...")
                Task {
                    await DishSyncService.shared.syncDishes(context: context)
                }
            }

        } catch {
            print("⚠️ Ошибка импорта из локального JSON: \(error)")
        }
    }

    // MARK: - Экспорт и сохранение в NAS
    func exportDishesToJSON(context: ModelContext) async {
        do {
            let dishes = try context.fetch(FetchDescriptor<Dish>())
            let encodedDishes = dishes.map {
                DishDECOD(
                    id: $0.id ?? UUID(),
                    name: $0.name,
                    about: $0.about,
                    imageBase64: $0.imageBase64,
                    category: $0.category ?? .lunch
                )
            }
            let container = DishesContainer(dishes: encodedDishes)
            let jsonData = try JSONEncoder().encode(container)
            let url = getDocumentsDirectory().appendingPathComponent("dishes.json")

            let existingData = try? Data(contentsOf: url)
            if existingData != jsonData {
                try jsonData.write(to: url)
                print("✅ Данные экспортированы в JSON: \(url)")
                try await APIService.shared.uploadDishes(encodedDishes)
                print("📤 Отправлено на NAS: \(encodedDishes.count) блюд")
            } else {
                print("⏩ Нет изменений, экспорт не требуется")
            }
        } catch {
            print("❌ Ошибка экспорта: \(error)")
            NotificationCenterService.shared.showError(
                "Ошибка при экспорте данных",
                resolution: "Проверьте файл dishes.json или соединение с NAS"
            )
        }
    }

     func isLocalNetworkReachable() async -> Bool {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        let testURL = URL(string: "http://192.168.1.168")!

        var request = URLRequest(url: testURL)
        request.httpMethod = "HEAD"
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
        } catch {
            print("🔌 Проверка сети не удалась: \(error.localizedDescription)")
        }
        return false
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print("✅ Локальная сеть доступна")
            } else {
                print("🚫 Локальная сеть НЕ доступна")
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }

    func areCredentialsPresent() -> Bool {
        let username = KeychainHelper.shared.read(key: "webdav_username")
        let password = KeychainHelper.shared.read(key: "webdav_password")
        return !(username?.isEmpty ?? true) && !(password?.isEmpty ?? true)
    }
}
