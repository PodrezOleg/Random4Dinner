//
//  MainContentView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.05.25.
//

import SwiftUI
import SwiftData

struct MainContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var dishes: [Dish]
    @Binding var selectedDish: Dish?
    @Binding var isAddingDish: Bool
    @Binding var isShowingList: Bool
    @Binding var errorMessage: String?
    @State private var isShowingSettings: Bool = false

    // Можно прокидывать выбранную группу в AddDishView и т.д.

    var body: some View {
        VStack(spacing: 20) {
           Spacer()
            DishSelectionButton
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
    }

    private var DishSelectionButton: some View {
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

