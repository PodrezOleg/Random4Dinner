//
//  MainContentView.swift
//  Random4Dinner
//
//  Created by Oleg Подрез on 13.05.25.
//

import SwiftUI
import SwiftData
import FirebaseAuth
import WebKit
import StoreKit
import AppIntents

struct MainContentView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var groupStore: GroupStore
    @Query private var dishes: [Dish]
    @AppStorage("loginMode") private var loginMode: String = ""
    
    @Binding var selectedDish: Dish?
    @Binding var isAddingDish: Bool
    @Binding var isShowingList: Bool
    @Binding var errorMessage: String?
    @State private var isShowingSettings: Bool = false

    @State private var isNavigatingToAddDish = false
    @State private var isNavigatingToDishList = false
    @State private var isNavigatingToSettings = false
    
    @State private var selectedDishId: UUID?
    @State private var deepLinkAlert: String?

    // Единый фильтр, совпадающий с DishListView
    private var filteredDishes: [Dish] {
        var seen = Set<UUID>()
        
        if loginMode == "guest" {
            return dishes.filter { d in
                let isLocal = (d.userId == nil)
                let noGroup = (d.groupId == nil || d.groupId?.isEmpty == true)
                return isLocal && noGroup && seen.insert(d.id).inserted
            }
        }
        if let gid = groupStore.selectedGroup?.id, !gid.isEmpty {
            return dishes.filter { d in
                (d.groupId == gid) && seen.insert(d.id).inserted
            }
        }
        // Fallback: личные блюда текущего пользователя (если группа не выбрана)
        if let uid = Auth.auth().currentUser?.uid {
            return dishes.filter { d in
                let isMine = (d.userId == uid)
                let noGroup = (d.groupId == nil || d.groupId?.isEmpty == true)
                return isMine && noGroup && seen.insert(d.id).inserted
            }
        }
        return []
    }

    var body: some View {
        NavigationStack {
            
            TabView {
                // dishes
            Tab("dishes", systemImage: "fork.knife.circle") {
                ZStack {
                    BackgroundView()
                        .ignoresSafeArea()
                    
                        .tabBarMinimizeBehavior(.onScrollDown)
                        .tabViewStyle(.sidebarAdaptable)
                            DishListView()
                        
                }
            }
                // add
                Tab("add", systemImage: "plus.app.fill"){
                    ZStack {
                        BackgroundView()
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            Spacer()
                            
                            VStack(spacing: 16) {
                                Button("Add Dish") {
                                    isNavigatingToAddDish = true
                                }
                                .buttonStyle(.glass)
                                .cornerRadius(25)
                                .padding()
                                
                                
                                Button("Импортировать блюда из JSON") {
                                    Task {
                                        await importDishesFromJSON(context: context, selectedGroupId: groupStore.selectedGroup?.id)
                                    }
                                }
                                .buttonStyle(.glass(.clear))
                                .backgroundExtensionEffect()
                                .controlSize(.extraLarge)
                            }
                            Spacer()
                        }
                        .padding()
                        
                    }
                    
                }
                
                
                // setting
                Tab("setting", systemImage: "gear.circle") {
                        SettingsView()
                    
                }
         
            
            }
          
            
            // Deep link
            .onOpenURL { url in
                let link = DeepLinkManager.parse(url: url)
                DeepLinkManager.handle(
                    link,
                    groupStore: groupStore,
                    openDish: { id in selectedDishId = id },
                    presentAlert: { msg in deepLinkAlert = msg }
                )
            }
            .alert("Ссылка", isPresented: Binding(
                get: { deepLinkAlert != nil },
                set: { if !$0 { deepLinkAlert = nil } }
            )) {
                Button("OK", role: .cancel) { deepLinkAlert = nil }
            } message: {
                Text(deepLinkAlert ?? "")
            }
        }
        // Сохранены листы как были, но AddDishView получает GroupStore явно
        .navigationDestination(isPresented: $isNavigatingToAddDish) {
            AddDishView()
                .environmentObject(groupStore)
        }

        .navigationDestination(isPresented: $isNavigatingToDishList) {
            DishListView()
                .environmentObject(groupStore)
        }

        .navigationDestination(isPresented: $isNavigatingToSettings) {
            SettingsView()
                .environmentObject(groupStore)
        }
    }

    // Кнопка Random с прежней логикой
    private var RandomButton: some View {
        Button("Random") {
            withAnimation(.snappy(duration: 0.5)) {
                guard let randomDish = filteredDishes.randomElement() else {
                    if loginMode == "guest" {
                        NotificationCenterService.shared.showInfo("Нет локальных блюд. Добавьте блюдо или импортируйте из JSON.")
                    } else if groupStore.selectedGroup != nil {
                        NotificationCenterService.shared.showInfo("В этой группе пока нет блюд. Добавьте блюдо.")
                    } else {
                        NotificationCenterService.shared.showInfo("Нет личных блюд. Добавьте блюдо.")
                    }
                    return
                }
                selectedDishId = randomDish.id
            }
        }
        .buttonStyle(.glass(.clear))
//        .frame(width: 600, height: 150)
//        .foregroundColor(.white)
//        .background(Color.orange)
//        .clipShape(Circle())
        .padding()
        .font(.title2.bold())
    }
}


#Preview {
    // Minimal preview for MainContentView with in-memory model and a dummy GroupStore
    @Previewable @State var selectedDish: Dish? = nil
    @Previewable @State var isAddingDish = false
    @Previewable @State var isShowingList = false
    @Previewable @State var errorMessage: String? = nil

    return MainContentView(
        selectedDish: $selectedDish,
        isAddingDish: $isAddingDish,
        isShowingList: $isShowingList,
        errorMessage: $errorMessage
    )
    .environmentObject(GroupStore())
    .modelContainer(for: Dish.self, inMemory: true)
}
