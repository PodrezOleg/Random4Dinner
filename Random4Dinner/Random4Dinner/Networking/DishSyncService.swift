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
        saveCredentialsIfNeeded()
    }

    private func saveCredentialsIfNeeded() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "credentialsSaved") {
            KeychainHelper.shared.save(key: "webdav_username", value: "")
            KeychainHelper.shared.save(key: "webdav_password", value: "")
            defaults.set(true, forKey: "credentialsSaved")
            print("🔐 Учетные данные сохранены в Keychain")
        }
    }

    func importInitialDishesIfNeeded(context: ModelContext) async {
        let alreadyImported = UserDefaults.standard.bool(forKey: "didImportInitialDishes")
        guard !alreadyImported else { return }

        await syncDishes(context: context)
        UserDefaults.standard.set(true, forKey: "didImportInitialDishes")
    }

    func syncDishes(context: ModelContext) async {
        guard await isLocalNetworkReachable() else {
            print("🚫 Локальная сеть недоступна")
            NotificationCenterService.shared.showWarning("Локальная сеть недоступна. Синхронизация не выполнена.")
            return
        }

        do {
            let remoteDishes = try await APIService.shared.fetchDishes()
            print("📥 Загружено с NAS: \(remoteDishes.count) блюд")

            let localDishes = try context.fetch(FetchDescriptor<Dish>())
            let localDict = Dictionary(uniqueKeysWithValues: localDishes.compactMap { dish in
                dish.id.map { ($0, dish) }
            })

            var changesMade = false

            for dish in remoteDishes {
                guard let id = dish.id else { continue }

                if let local = localDict[id] {
                    if local.name != dish.name || local.about != dish.about || local.imageBase64 != dish.imageBase64 {
                        local.name = dish.name
                        local.about = dish.about
                        local.imageBase64 = dish.imageBase64
                        changesMade = true
                    }
                } else {
                    context
                        .insert(
                            Dish(
                                name: dish.name,
                                about: dish.about,
                                imageBase64: dish.imageBase64,
                                category: dish.category
                            )
                        )
                    changesMade = true
                }
            }

            if changesMade {
                try context.save()
            }
        } catch {
            print("❌ Ошибка синхронизации: \(error)")
            NotificationCenterService.shared.showError("Ошибка синхронизации", resolution: "Проверьте подключение к NAS или доступ к файлу dishes.json")
        }
    }

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
                NotificationCenterService.shared.showSuccess("Блюда успешно отправлены на сервер")
            } else {
                print("⏩ Нет изменений, экспорт не требуется")
                NotificationCenterService.shared.showWarning("Нет изменений, отправка не требуется")
            }
        } catch {
            print("❌ Ошибка экспорта: \(error)")
            NotificationCenterService.shared.showError("Ошибка экспорта блюд", resolution: "Проверьте подключение к NAS и корректность формата JSON")
        }
    }
    
    private func isLocalNetworkReachable() async -> Bool {
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
}
