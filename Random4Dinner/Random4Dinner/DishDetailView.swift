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
            if let imageData = dish.image, let uiImage = UIImage(data: imageData) {
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
                    .padding()
            }

            Text(dish.name)
                .font(.largeTitle)
                .bold()
                .padding(.top)

            Text(dish.about)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()

            Spacer()
        }
        .padding()
        .navigationTitle(dish.name)
    }
}
