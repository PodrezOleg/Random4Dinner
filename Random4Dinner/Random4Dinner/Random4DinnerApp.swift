//
//  Random4DinnerApp.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import SwiftData
import GoogleSignIn

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

    init() {
        // Здесь конфигурируем Google Sign-In один раз при запуске
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "336346687083-pl7ar4iqupk08hjue4mlbkfijd1b0ae9.apps.googleusercontent.com"
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay(NotificationBannerView())
                .environment(\.modelContext, sharedModelContainer.mainContext)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
