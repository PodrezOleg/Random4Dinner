//
//  ContentView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var dishes: [Dish]
    @State private var selectedDish: Dish?
    @State private var isAddingDish = false
    @State private var isShowingList = false  // Новая переменная для показа списка блюд

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
                .font(.title2.bold()) // Увеличим шрифт для визуального эффекта
                
                .navigationDestination(item: $selectedDish) { dish in
                    DishDetailView(dish: dish)
                }
            }
            .toolbar {
                // Кнопка добавления нового блюда
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        isAddingDish = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                // Кнопка просмотра списка блюд
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        isShowingList = true
                    }) {
                        Image(systemName: "fork.knife")
                    }
                }
            }
            .sheet(isPresented: $isAddingDish) {
                AddDishView()
            }
            .sheet(isPresented: $isShowingList) {
                DishListView()  // Показываем список блюд
            }
        }
    }
}
