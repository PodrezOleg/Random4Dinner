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

    // MARK: - Удаление дубликатов блюд по id
    func removeDuplicateDishes(context: ModelContext) {
        do {
            let allDishes = try context.fetch(FetchDescriptor<Dish>())
            var seen: Set<UUID> = []
            var duplicates: [Dish] = []

            for dish in allDishes {
                if seen.contains(dish.id) {
                    duplicates.append(dish)
                } else {
                    seen.insert(dish.id)
                }
            }

            for duplicate in duplicates {
                context.delete(duplicate)
            }

            if !duplicates.isEmpty {
                try context.save()
                print("🧹 Удалено дубликатов блюд: \(duplicates.count)")
                NotificationCenterService.shared.showInfo("🧹 Удалено дубликатов блюд: \(duplicates.count)")
            } else {
                print("✅ Дубликатов блюд не найдено")
            }

        } catch {
            print("❌ Ошибка при удалении дубликатов: \(error)")
            NotificationCenterService.shared.showError(
                "Ошибка при очистке базы от дубликатов",
                resolution: "Проверьте данные вручную"
            )
        }
    }

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

            var localDict: [UUID: Dish] = Dictionary(
                uniqueKeysWithValues: localDishes.compactMap { dish in
                    guard let id = dish.id as UUID? else { return nil }
                    return (id, dish)
                }
            )

            var remoteDict: [UUID: DishDECOD] = Dictionary(
                uniqueKeysWithValues: remoteDishes.compactMap { dish in
                    guard let id = dish.id else { return nil }
                    return (id, dish)
                }
            )

            var changesMade = false
            var updatedCount = 0
            var addedCount = 0
            var deletedCount = 0

            for (id, remoteDish) in remoteDict {
                if let localDish = localDict[id] {
                    // Обновляем только если есть реальные изменения
                    if localDish.name != (remoteDish.name ?? "") ||
                        localDish.about != (remoteDish.about ?? "") ||
                        localDish.imageBase64 != (remoteDish.imageBase64 ?? "") ||
                        localDish.category != (remoteDish.category ?? .lunch) {

                        localDish.updateFromDecoded(remoteDish)
                        updatedCount += 1
                        changesMade = true
                    }
                    localDict.removeValue(forKey: id)
                } else {
                    // Проверим, не существует ли уже объект с таким ID в контексте (защита от дубликатов)
                    if try context.fetch(FetchDescriptor<Dish>(predicate: #Predicate { $0.id == id })).isEmpty {
                        context.insert(Dish(from: remoteDish))
                        addedCount += 1
                        changesMade = true
                    } else {
                        print("⚠️ Пропущен дубликат при вставке с ID: \(id)")
                    }
                }
            }

            self.removeDuplicateDishes(context: context)

            // Удаляем блюда, которых больше нет на сервере
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
                resolution: "Проверьте подключение к NAS или повторите позже"
            )
        }
    }
    // MARK: - Импорт из локального файла JSON
    func importDishesFromLocalJSON(context: ModelContext) {
        let url = getDocumentsDirectory().appendingPathComponent("dishes.json")
        guard let data = try? Data(contentsOf: url) else {
            print("📂 Локальный файл не найден")
            return
        }

        do {
            let container = try JSONDecoder().decode(DishesContainer.self, from: data)
            let existingDishes = try context.fetch(FetchDescriptor<Dish>())
            var localDict: [UUID: Dish] = existingDishes.reduce(into: [:]) { dict, dish in
                if dict[dish.id] == nil {
                    dict[dish.id] = dish
                }
            }
            var addedCount = 0
            var updatedCount = 0
            var changesMade = false

            for decoded in container.dishes {
                guard let id = decoded.id else { continue }

                if let localDish = localDict[id] {
                    localDish.updateFromDecoded(decoded)
                    updatedCount += 1
                    changesMade = true
                    localDict.removeValue(forKey: id)
                } else {
                    // Проверим, не существует ли уже объект с таким ID в контексте (защита от дубликатов)
                    if try context.fetch(FetchDescriptor<Dish>(predicate: #Predicate { $0.id == id })).isEmpty {
                        context.insert(Dish(from: decoded))
                        addedCount += 1
                        changesMade = true
                    } else {
                        print("⚠️ Пропущен дубликат при импорте из JSON с ID: \(id)")
                    }
                }
            }

            self.removeDuplicateDishes(context: context)

            // Не удаляем старые блюда при локальном импорте (можно добавить по желанию)

            if changesMade {
                try context.save()
                print("📦 Импорт из локального JSON завершён. ➕ Добавлены: \(addedCount), 🔄 Обновлены: \(updatedCount)")
            } else {
                print("⏩ Импорт из локального JSON: нет изменений")
            }

            // ⏱️ Попытка синхронизации через 5 секунд
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                NotificationCenterService.shared.showInfo("Попытка синхронизации с NAS...")
                Task {
                    await DishSyncService.shared.syncDishes(context: context)
                }
            }

        } catch {
            print("⚠️ Ошибка импорта из локального JSON: \(error)")
        }
    }
        //MARK: - Импорт из NAS
    func importDishesFromNASIfNeeded(context: ModelContext) async {
        do {
            let remoteDishes = try await APIService.shared.fetchDishes()
            let existingDishes = try context.fetch(FetchDescriptor<Dish>())
            let existingIDs = Set(existingDishes.compactMap { $0.id })

            var addedCount = 0

            for remote in remoteDishes {
                guard let id = remote.id, !existingIDs.contains(id) else {
                    continue // блюдо уже есть, пропускаем
                }

                let newDish = Dish(
                    name: remote.name ?? "",
                    about: remote.about ?? "",
                    imageBase64: remote.imageBase64 ?? "",
                    category: remote.category ?? .lunch
                )
                newDish.id = id

                context.insert(newDish)
                addedCount += 1
            }

            if addedCount > 0 {
                try context.save()
                print("📥 Импорт с NAS завершён: добавлено \(addedCount) новых блюд")
                NotificationCenterService.shared.showSuccess("📥 Импортировано \(addedCount) новых блюд с NAS")
            } else {
                print("⏩ Импорт с NAS: новых блюд нет")
                NotificationCenterService.shared.showInfo("⏩ Новых блюд на NAS не найдено")
            }

        } catch {
            print("❌ Ошибка загрузки блюд с NAS: \(error)")
            NotificationCenterService.shared.showError(
                "Ошибка при импорте блюд с NAS",
                resolution: "Проверьте соединение с NAS или правильность файла"
            )
        }
    }
    // MARK: - Экспорт и сохранение в NAS
    func exportDishesToJSON(context: ModelContext) async {
        do {
            let dishes = try context.fetch(FetchDescriptor<Dish>())
            let uniqueDishes = Dictionary(grouping: dishes, by: \.id).compactMapValues { $0.first }.values
            let encodedDishes = uniqueDishes.map {
                DishDECOD(
                    id: $0.id,
                    name: $0.name,
                    about: $0.about,
                    imageBase64: $0.imageBase64,
                    category: $0.category ?? .lunch
                )
            }

            let container = DishesContainer(dishes: encodedDishes)
            let jsonData = try JSONEncoder().encode(container)
            let url = getDocumentsDirectory().appendingPathComponent("dishes.json")

            // Только если данные реально изменились
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
        let testURL = URL(string: "http://192.168.1.168:8888/remote.php/dav/files/Podrez/Random4DinnerApp/dishes.json")!

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
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("✅ Локальная сеть доступна")
                if let context = self?.latestContext {
                    Task {
                        print("🌐 Повторная синхронизация при появлении сети...")
                        await self?.syncDishes(context: context)
                    }
                }
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
    private var latestContext: ModelContext?

    func setLatestContext(_ context: ModelContext) {
        latestContext = context
    }
}
