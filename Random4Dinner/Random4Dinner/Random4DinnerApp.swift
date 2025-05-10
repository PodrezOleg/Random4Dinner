//
//  Random4DinnerApp.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import SwiftData


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }
}

@main
struct Random4DinnerApp: App {

    // Настройка SwiftData
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Dish.self, // Используем правильную модель данных
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay(NotificationBannerView())
                .environment(\.modelContext, sharedModelContainer.mainContext) // Передаём контейнер данных
        }
    }
}

