//
//  DishListView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import SwiftData

struct DishListView: View {
    @Environment(\.modelContext) private var context
    @Query private var dishes: [Dish]

    var body: some View {
        NavigationView {
            List {
                ForEach(dishes) { dish in
                    DishRowView(dish: dish)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        context.delete(dishes[index])
                    }
                }
            }
            .navigationTitle("Мои блюда")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: AddDishView()) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// Вынесем строку блюда в отдельный `View`
struct DishRowView: View {
    let dish: Dish

    var body: some View {
        NavigationLink(destination: DishDetailView(dish: dish)) {
            HStack {
                DishImageView(imageData: dish.image)
                VStack(alignment: .leading) {
                    Text(dish.name)
                        .font(.headline)
                    Text(dish.about)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// Вынесем обработку изображения в отдельный `View`
struct DishImageView: View {
    let imageData: Data?

    var body: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: "photo")
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .foregroundColor(.gray)
                .opacity(0.5)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
