//
//  Random4DinnerApp.swift
//  Random4Dinner
//
//  Created by Oleg Podрез on 11.03.25.
//

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct Random4DinnerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var groupStore = GroupStore()

    // Состояния для диплинков
    @State private var deepLinkAlert: String?
    @State private var pendingDishId: UUID?

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
            NavigationStack {
                // Встраиваем ваш основной UI. Здесь у вас сейчас ContentView из примера Firebase Messaging.
                // Если у вас есть свой корневой экран, замените на него.
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
                        // Сначала даём шанс Google Sign-In
                        if GIDSignIn.sharedInstance.handle(url) {
                            return
                        }
                        // Разбираем наш диплинк
                        let link = DeepLinkManager.parse(url: url)
                        handleDeepLink(link)
                    }
                    .alert("Ссылка", isPresented: Binding(
                        get: { deepLinkAlert != nil },
                        set: { if !$0 { deepLinkAlert = nil } }
                    )) {
                        Button("OK", role: .cancel) { deepLinkAlert = nil }
                    } message: {
                        Text(deepLinkAlert ?? "")
                    }
                    .navigationDestination(item: Binding(
                        get: { pendingDishId },
                        set: { pendingDishId = $0 }
                    )) { id in
                        DishDetailView(dishId: id)
                    }
            }
        }
    }

    // MARK: - Deep Link handling

    private func handleDeepLink(_ deepLink: DeepLink) {
        switch deepLink {
        case .invite(let groupId, _):
            // Сохраняем выбранную группу локально, чтобы пользователь увидел её в "Группах"
            groupStore.selectedGroup = UserGroup(id: groupId, name: "", ownerId: "", members: [])
            deepLinkAlert = "Приглашение получено. Откройте раздел “Мои группы”, чтобы присоединиться."
        case .dish(let id):
            // Навигация к блюду
            pendingDishId = id
        case .unknown:
            deepLinkAlert = "Не удалось обработать ссылку."
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
