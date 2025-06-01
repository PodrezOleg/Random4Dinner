//
//  AppLifecycleModifier.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.05.25.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct AppLifecycleModifier: ViewModifier {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var groupStore: GroupStore
    @Query private var dishes: [Dish]
    @Binding var errorMessage: String?
    @State private var needsLoginResolver = false

    func body(content: Content) -> some View {
        content
            .background(loginResolverView)
            .onAppear {
                print("onAppear AppLifecycleModifier, isSignedIn: \(GoogleAuthManager.shared.isSignedIn)")
                if !GoogleAuthManager.shared.isSignedIn {
                    print("Пользователь не залогинен, показываем логин")
                    needsLoginResolver = true
                } else {
                    print("Пользователь уже залогинен, обновляем группы и блюда")
                    updateGroupsAndSync()
                }
            }
            .onChange(of: dishes, initial: false) { _, _ in
                updateGroupsAndSync()
            }
            .onChange(of: UIApplication.shared.connectedScenes.first?.activationState, initial: false) { _, newPhase in
                if newPhase == .background {
                    updateGroupsAndSync()
                }
            }
    }

    @ViewBuilder
    private var loginResolverView: some View {
        if needsLoginResolver {
            ViewControllerResolver { controller in
                print("Показываем Google Sign-In") // <-- ВСТАВЬ СЮДА!
                GoogleAuthManager.shared.signIn(presenting: controller) { success in
                    needsLoginResolver = false
                    print(success ? "✅ Вход выполнен" : "❌ Вход не выполнен")
                    if success {
                        updateGroupsAndSync()
                    } else {
                        errorMessage = "Не удалось войти в Google"
                    }
                }
            }
            .frame(width: 0, height: 0)
        }
    }

    private func updateGroupsAndSync() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        groupStore.fetchGroups(for: userId) {
            // Синхронизируем блюда пользователя + групп
            Task { @MainActor in
                do {
                    try await DishSyncService.shared.syncDishes(context: context, userGroups: groupStore.groups.map { $0.id })
                } catch {
                    errorMessage = error.localizedDescription
                    print("Ошибка синхронизации: \(error)")
                }
            }
        }
    }
}
