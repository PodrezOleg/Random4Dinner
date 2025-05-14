//
//  AppLifecycleModifier.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.05.25.
//

import SwiftUI
import SwiftData

struct AppLifecycleModifier: ViewModifier {
    @Environment(\.modelContext) private var context
    @Query private var dishes: [Dish]

    @Binding var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.async {
                    // 🔐 Авторизация через Google
                    if !GoogleAuthManager.shared.isSignedIn {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootVC = windowScene.windows.first?.rootViewController {
                            GoogleAuthManager.shared.signIn(presenting: rootVC) { success in
                                print(success ? "✅ Вход выполнен" : "❌ Вход не выполнен")
                            }
                        }
                    }
                }

                // 🔄 Синхронизация
                Task {
                    await MainActor.run {
                        DishSyncService.shared.removeDuplicateDishes(context: context)
                        DishSyncService.shared.setLatestContext(context)
                    }

                    await DishSyncService.shared.importFromGoogleDrive(context: context)
                    await DishSyncService.shared.syncDishes(context: context)
                }
            }
            .onChange(of: dishes, initial: false) { _, _ in
                Task { @MainActor in
                    await DishSyncService.shared.exportToGoogleDrive(context: context)
                }
            }
            .onChange(of: UIApplication.shared.connectedScenes.first?.activationState, initial: false) { _, newPhase in
                if newPhase == .background {
                    Task { @MainActor in
                        await DishSyncService.shared.exportToGoogleDrive(context: context)
                    }
                }
            }
    }
}
