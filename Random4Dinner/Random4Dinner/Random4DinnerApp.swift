//
//  Random4DinnerApp.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import SwiftData
import GoogleSignIn
import FirebaseCore

@main
struct Random4DinnerApp: App {
    // Настройка SwiftData на уровне структуры
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Dish.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Firebase
        FirebaseManager.shared.configure()
        // Google Sign-In
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
