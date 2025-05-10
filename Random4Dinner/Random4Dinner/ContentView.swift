//  ContentView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var dishes: [Dish]
    
    @State private var selectedDish: Dish?
    @State private var isAddingDish = false
    @State private var isShowingList = false
    @State private var errorMessage: String? = nil
    @State private var showKeychainSetup = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Button("Выбрать еду") {
                    withAnimation(.snappy(duration: 0.5)) {
                        selectedDish = dishes.randomElement()
                    }
                }
                .frame(width: 600, height: 150)
                .foregroundColor(.white)
                .background(Color.orange)
                .clipShape(Circle())
                .padding()
                .font(.title2.bold())
                .navigationDestination(item: $selectedDish) { dish in
                    DishDetailView(dish: dish)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingDish = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingList = true
                    } label: {
                        Image(systemName: "fork.knife")
                    }
                }
            }
            .sheet(isPresented: $isAddingDish) {
                AddDishView()
            }
            .sheet(isPresented: $isShowingList) {
                DishListView()
            }
            .sheet(isPresented: $showKeychainSetup) {
                KeychainSetupView()
            }
            .onAppear {
                // 1. Импорт локальных блюд сразу
                DishSyncService.shared.importDishesFromLocalJSON(context: context)

                // 2. Через 5 секунд — попытка синхронизации с NAS
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 секунд

                    if await DishSyncService.shared.isLocalNetworkReachable() {
                        await DishSyncService.shared.syncDishes(context: context)
                    } else {
                        NotificationCenterService.shared.showWarning("NAS пока недоступен, блюда обновятся позже")
                    }
                }

                // 3. Пингуем NAS отдельно
                Task { @MainActor in
                    await NASPingService.shared.pingNAS()
                }

                if !DishSyncService.shared.areCredentialsPresent() {
                    showKeychainSetup = true
                }
            }
            .onChange(of: dishes, initial: false) { _, _ in
                Task { @MainActor in
                    await DishSyncService.shared.exportDishesToJSON(context: context)
                }
            }
            .onChange(of: scenePhase, initial: false) { _, newPhase in
                if newPhase == .background {
                    Task { @MainActor in
                        await DishSyncService.shared.exportDishesToJSON(context: context)
                    }
                }
            }
            .alert("Ошибка", isPresented: Binding.constant(errorMessage != nil)) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Произошла неизвестная ошибка")
            }
        }
    }
}

extension Dish {
    func update(from decoded: DishDECOD) {
        self.name = decoded.name
        self.about = decoded.about
        self.imageBase64 = decoded.imageBase64
    }
}
