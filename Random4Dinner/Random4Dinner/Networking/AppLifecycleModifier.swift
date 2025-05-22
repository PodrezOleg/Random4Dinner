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
    @State private var needsLoginResolver = false

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if needsLoginResolver {
                        ViewControllerResolver { controller in
                            GoogleAuthManager.shared.signIn(presenting: controller) { success in
                                needsLoginResolver = false
                                print(success ? "✅ Вход выполнен" : "❌ Вход не выполнен")
                                if success {
                                    Task { @MainActor in
                                        await DishSyncService.shared.importFromGoogleDrive(context: context)
                                        await DishSyncService.shared.syncDishes(context: context)
                                    }
                                } else {
                                    errorMessage = "Не удалось войти в Google"
                                }
                            }
                        }
                        .frame(width: 0, height: 0)
                    }
                }
            )
            .onAppear {
                if !GoogleAuthManager.shared.isSignedIn {
                    needsLoginResolver = true
                } else {
                    Task { @MainActor in
                        await DishSyncService.shared.importFromGoogleDrive(context: context)
                        await DishSyncService.shared.syncDishes(context: context)
                    }
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
