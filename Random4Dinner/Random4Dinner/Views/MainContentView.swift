//
//  MainContentView.swift
//  Random4Dinner
//
//  Created by Oleg Podрез on 13.05.25.
//

import SwiftUI
import SwiftData

struct MainContentView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var groupStore: GroupStore
    @Query private var dishes: [Dish]
    // Раньше: @Binding var selectedDish: Dish?
    @Binding var selectedDish: Dish?
    @Binding var isAddingDish: Bool
    @Binding var isShowingList: Bool
    @Binding var errorMessage: String?
    @State private var isShowingSettings: Bool = false

    // Добавляем безопасный id для навигации
    @State private var selectedDishId: UUID?
    @State private var deepLinkAlert: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            DishSelectionButton

            // Добавь кнопку импорта здесь 👇
            Button("Импортировать блюда из JSON") {
                Task {
                    await importDishesFromJSON(context: context, selectedGroupId: groupStore.selectedGroup?.id)
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
            CustomTabBar(
                isAddingDish: $isAddingDish,
                isShowingList: $isShowingList,
                isShowingSettings: $isShowingSettings
            )
        }
        .modifier(CombinedModifiers(
            isAddingDish: $isAddingDish,
            isShowingList: $isShowingList,
            isShowingSettings: $isShowingSettings,
            errorMessage: $errorMessage
        ))
        // Навигация по id (исключаем передачу @Model)
        .navigationDestination(item: $selectedDishId) { dishId in
            DishDetailView(dishId: dishId)
        }
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

    private var DishSelectionButton: some View {
        Button("Выбрать еду") {
            withAnimation(.snappy(duration: 0.5)) {
                if let randomDish = dishes.randomElement() {
                    selectedDishId = randomDish.id
                }
            }
        }
        .frame(width: 600, height: 150)
        .foregroundColor(.white)
        .background(Color.orange)
        .clipShape(Circle())
        .padding()
        .font(.title2.bold())
    }

    struct CombinedModifiers: ViewModifier {
        @Binding var isAddingDish: Bool
        @Binding var isShowingList: Bool
        @Binding var isShowingSettings: Bool
        @Binding var errorMessage: String?

        func body(content: Content) -> some View {
            content
                .modifier(DishSheets(
                    isAddingDish: $isAddingDish,
                    isShowingList: $isShowingList,
                    isShowingSettings: $isShowingSettings
                ))
        }
    }

    struct DishSheets: ViewModifier {
        @Binding var isAddingDish: Bool
        @Binding var isShowingList: Bool
        @Binding var isShowingSettings: Bool
        @EnvironmentObject var groupStore: GroupStore

        func body(content: Content) -> some View {
            content
                .sheet(isPresented: $isAddingDish) {
                    AddDishView()
                }
                .sheet(isPresented: $isShowingList) {
                    DishListView()
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView().environmentObject(groupStore)
                }
            }
        }
    }

    struct CustomTabBar: View {
        @Binding var isAddingDish: Bool
        @Binding var isShowingList: Bool
        @Binding var isShowingSettings: Bool

        var body: some View {
            HStack {
                Spacer()
                Button {
                    isShowingList = true
                } label: {
                    Image(systemName: "fork.knife")
                        .font(.title)
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    isAddingDish = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title)
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding()
            .background(Color(UIColor.systemGray6))
        }
    }

