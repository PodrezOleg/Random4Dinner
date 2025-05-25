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

    // Можно прокидывать выбранную группу в AddDishView и т.д.

    var body: some View {
        VStack(spacing: 20) {
            DishSelectionButton
        }
        .modifier(CombinedModifiers(
            isAddingDish: $isAddingDish,
            isShowingList: $isShowingList,
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
        @Binding var errorMessage: String?

        func body(content: Content) -> some View {
            content
                .modifier(TopToolbar(
                    isAddingDish: $isAddingDish,
                    isShowingList: $isShowingList,
                    errorMessage: $errorMessage
                ))
                .modifier(DishSheets(
                    isAddingDish: $isAddingDish,
                    isShowingList: $isShowingList
                ))
        }
    }

    struct TopToolbar: ViewModifier {
        @Environment(\.modelContext) private var context
        @Binding var isAddingDish: Bool
        @Binding var isShowingList: Bool
        @Binding var errorMessage: String?

        func body(content: Content) -> some View {
            content
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
        }
    }

    struct DishSheets: ViewModifier {
        @Binding var isAddingDish: Bool
        @Binding var isShowingList: Bool

        func body(content: Content) -> some View {
            content
                .sheet(isPresented: $isAddingDish) {
                    AddDishView()
                }
                .sheet(isPresented: $isShowingList) {
                    DishListView()
                }
        }
    }
}
