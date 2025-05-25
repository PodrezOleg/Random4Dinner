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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate    // <-- Важно!

    @StateObject var groupStore = GroupStore()
    // Настройка SwiftData
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay(NotificationBannerView())
                .environment(\.modelContext, sharedModelContainer.mainContext)
                .environmentObject(groupStore)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
