//
//  DishDetailView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI

struct DishDetailView: View {
    let dish: Dish
    
    var body: some View {
        VStack {
            if let imageData = dish.imageBase64, let uiImage = UIImage(data: Data(base64Encoded: imageData) ?? Data()) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 300)
                    .foregroundColor(.gray)
                    .opacity(0.5)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding()
                    
            }
            
            Text(dish.name)
                .font(.largeTitle)
                .bold()
                .padding(.top)
            
            Text(dish.about)
                .frame(height: 150) // Высота поля для ввода текста
                .multilineTextAlignment(.leading) // Выравнивание текста
                .cornerRadius(10) // Закруглённые края
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1) // Обводка для эстетики
                )
                .padding()
        }
        Spacer()
        .padding()
        .navigationTitle(dish.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: EditDishView(dish: dish)) {
                    Text("Редактировать")
                }
            }
        }
    }
}
