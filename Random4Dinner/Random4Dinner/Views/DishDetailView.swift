//
//  DishDetailView.swift
//  Random4Dinner
//
//  Created by Oleg Podрез on 11.03.25.
//  Обновлено: загрузка Dish по id для избежания detached.
//

import SwiftUI
import SwiftData

struct DishDetailView: View {
    let dishId: UUID
    
    @Environment(\.modelContext) private var context
    @State private var dish: Dish?

    var body: some View {
        Group {
            if let dish {
                VStack {
                    if let base64 = dish.imageBase64,
                       let imageData = Data(base64Encoded: base64),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding()
                    } else if let urlString = dish.imageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFit()
                            case .failure(_): Image(systemName: "photo").resizable().scaledToFit().foregroundColor(.gray).opacity(0.5)
                            case .empty: ProgressView()
                            @unknown default: EmptyView()
                            }
                        }
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
                        .frame(height: 150)
                        .multilineTextAlignment(.leading)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
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
            } else {
                ProgressView().onAppear(perform: loadDish)
            }
        }
        .onAppear(perform: loadDish)
    }

    private func loadDish() {
        if dish != nil { return }
        let descriptor = FetchDescriptor<Dish>(
            predicate: #Predicate { $0.id == dishId },
            sortBy: []
        )
        if let fetched = try? context.fetch(descriptor).first {
            dish = fetched
        }
    }
}

