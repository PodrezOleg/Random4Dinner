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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var groupStore = GroupStore()

    // Обычный контейнер без версионированных схем
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Recipe.self,
            Dish.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
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
                .onAppear {
                    Task { @MainActor in
                        upgradeToLastModifiedIfNeeded(context: sharedModelContainer.mainContext)
                    }
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

// MARK: - Одноразовый апгрейд старых записей
@MainActor
private func upgradeToLastModifiedIfNeeded(context: ModelContext) {
    let flagKey = "didUpgrade_lastModified_v2"
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: flagKey) else { return }

    let descriptor = FetchDescriptor<Recipe>(
        predicate: #Predicate { $0.lastModified == nil }
    )
    if let items = try? context.fetch(descriptor), !items.isEmpty {
        for r in items {
            // ставим разумное значение: createdAt, иначе now
            r.lastModified = r.createdAt
        }
        try? context.save()
    }
    defaults.set(true, forKey: flagKey)
}
