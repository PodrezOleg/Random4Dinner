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
    @AppStorage("keychainSetupDone") private var keychainSetupDone: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
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
                
                Button("📥 Загрузить и показать блюда с NAS") {
                    Task {
                        do {
                            let remoteDishes = try await APIService.shared.fetchDishes()
                            await MainActor.run {
                                for remote in remoteDishes {
                                    guard let id = remote.id else { continue }
                                    
                                    let dish = Dish(
                                        name: remote.name ?? "",
                                        about: remote.about ?? "",
                                        imageBase64: remote.imageBase64 ?? "",
                                        category: remote.category ?? .lunch
                                    )
                                    dish.id = id
                                    context.insert(dish)
                                }
                                
                                try? context.save()
                                NotificationCenterService.shared.showSuccess("📥 Добавлено в базу: \(remoteDishes.count) блюд")
                            }
                        } catch {
                            NotificationCenterService.shared.showError("Не удалось загрузить с NAS", resolution: error.localizedDescription)
                        }
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
                    Task {
                        // 🧹 Удаляем дубликаты до всех операций
                        await MainActor.run {
                            DishSyncService.shared.removeDuplicateDishes(context: context)
                              }
                        // 1. Всегда сначала грузим локальный JSON
                        await MainActor.run {
                            DishSyncService.shared.importDishesFromLocalJSON(context: context)
                            DishSyncService.shared.setLatestContext(context)
                        }
                        
                        // 2. Пробуем NAS: если доступен — сразу обновляем
                        if await DishSyncService.shared.isLocalNetworkReachable() {
                            await DishSyncService.shared.syncDishes(context: context)
                        } else {
                            NotificationCenterService.shared.showWarning("NAS пока недоступен, блюда загружены из памяти")
                        }
                        
                        // 3. Пингуем NAS отдельно (для иконки/статуса)
                        await NASPingService.shared.pingNAS()
                        
                        // 4. Проверка Keychain
                        if !keychainSetupDone && !DishSyncService.shared.areCredentialsPresent() {
                            await MainActor.run {
                                showKeychainSetup = true
                            }
                        }
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
}
    
    extension Dish {
        func update(from decoded: DishDECOD) {
            self.name = decoded.name ?? ""
            self.about = decoded.about ?? ""
            self.imageBase64 = decoded.imageBase64
        }
    }

