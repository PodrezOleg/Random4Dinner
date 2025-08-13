//
//  DishRow.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.08.25.
//

import SwiftUI

struct DishRow: View {
    let dish: Dish
    var body: some View {
        HStack {
            if let urlString = dish.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure(_): Color.gray.opacity(0.2)
                    case .empty: ProgressView()
                    @unknown default: EmptyView()
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // плейсхолдер
                Image(systemName: "photo")
                    .frame(width: 56, height: 56)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(dish.name).font(.headline)
            Spacer()
        }
    }
}
