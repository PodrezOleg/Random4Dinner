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
    
    private var latestContext: ModelContext?
    
    func setLatestContext(_ context: ModelContext) {
        latestContext = context
    }
    
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
    
    // MARK: - Импорт с Google Drive
    func importFromGoogleDrive(context: ModelContext) async {
        do {
            let data = try await withCheckedThrowingContinuation { continuation in
                GoogleDriveService.shared.downloadDishesJSON { result in
                    switch result {
                    case .success(let data):
                        continuation.resume(returning: data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            let container = try JSONDecoder().decode(DishesContainer.self, from: data)
            let localDishes = try context.fetch(FetchDescriptor<Dish>())
            
            var localDict = Dictionary(uniqueKeysWithValues: localDishes.map { ($0.id, $0) })
            var updated = 0
            var added = 0
            var changesMade = false
            
            for decoded in container.dishes {
                guard let id = decoded.id else { continue }
                if let local = localDict[id] {
                    local.updateFromDecoded(decoded)
                    updated += 1
                    changesMade = true
                    localDict.removeValue(forKey: id)
                } else {
                    context.insert(Dish(from: decoded))
                    added += 1
                    changesMade = true
                }
            }
            
            for (_, dish) in localDict {
                context.delete(dish)
                changesMade = true
            }
            
            try context.save()
            
            if changesMade {
                NotificationCenterService.shared.showSuccess("📥 Импортировано: ➕ \(added), 🔄 \(updated)")
            } else {
                NotificationCenterService.shared.showInfo("⏩ Нет изменений при импорте из Google Drive")
            }
            
        } catch {
            print("❌ Ошибка импорта из Google Drive: \(error)")
            NotificationCenterService.shared.showError("Ошибка импорта", resolution: error.localizedDescription)
        }
    }
    
    // MARK: - Экспорт в Google Drive
    func exportToGoogleDrive(context: ModelContext) async {
        do {
            let dishes = try context.fetch(FetchDescriptor<Dish>())
            let decoded = dishes.map { DishDECOD(id: $0.id, name: $0.name, about: $0.about, imageBase64: $0.imageBase64, category: $0.category ?? .lunch) }
            let container = DishesContainer(dishes: decoded)
            let data = try JSONEncoder().encode(container)
            try await GoogleDriveService.shared.uploadDishesJSON(data)
            print("📤 Экспортировано блюд в Google Drive: \(dishes.count)")
        } catch {
            print("❌ Ошибка экспорта в Google Drive: \(error)")
            NotificationCenterService.shared.showError("Ошибка экспорта", resolution: error.localizedDescription)
        }
    }
    
    // MARK: - Проверка доступности локальной сети
    func isLocalNetworkReachable() async -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "LocalNetworkMonitor")
        
        return await withCheckedContinuation { continuation in
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: queue)
        }
    }

    // MARK: - Проверка наличия учетных данных
    func areCredentialsPresent() -> Bool {
        // Здесь может быть логика проверки Keychain или других данных
        return false
    }

    // MARK: - Синхронизация данных (импорт + экспорт)
    func syncDishes(context: ModelContext) async {
        await importFromGoogleDrive(context: context)
        await exportToGoogleDrive(context: context)
    }
    
    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                print("✅ Сеть доступна")
                if let context = self?.latestContext {
                    Task {
                        print("🌐 Синхронизация при появлении сети...")
                        await self?.importFromGoogleDrive(context: context)
                    }
                }
            } else {
                print("🚫 Сеть недоступна")
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
}
