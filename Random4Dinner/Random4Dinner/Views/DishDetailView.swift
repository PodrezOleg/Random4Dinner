//
//  DishDetailView.swift
//  Random4Dinner
//
//  Created by Oleg Podрез on 11.03.25.
//  Обновлено: загрузка Dish по id для избежания detached.
//

import SwiftUI
import SwiftData
import UIKit

struct DishDetailView: View {
    let dishId: UUID
    
    @Environment(\.modelContext) private var context
    @State private var dish: Dish?

    var body: some View {
        Group {
            if let dish {
                VStack {
                    if let b64 = dish.imageBase64 {
                        let payload = b64.split(separator: ",").last.map(String.init) ?? b64
                        if let imageData = Data(base64Encoded: payload),
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
                ProgressView()
            }
        }
        .task { await loadDish() }
    }

    @MainActor
    private func loadDish() async {
        guard dish == nil else { return }
        let descriptor = FetchDescriptor<Dish>(
            predicate: #Predicate { $0.id == dishId },
            sortBy: []
        )
        do {
            dish = try context.fetch(descriptor).first
        } catch {
            // Optional: log or present a lightweight fallback if needed
            print("DishDetailView: failed to fetch dish by id \(dishId): \(error)")
        }
    }
}

#Preview {
    // Use the same persistent container as the running app
    let app = Random4DinnerApp()
    let container = app.sharedModelContainer
    let context = container.mainContext

    // Try to fetch any existing Dish from your real store
    let existing = try? context.fetch(FetchDescriptor<Dish>(sortBy: [])).first

    if let dish = existing {
        // Show the real dish detail using the real container
        return DishDetailView(dishId: dish.id)
            .environment(\.modelContext, context)
            .modelContainer(container)
    } else {
        // If no data yet, present a helpful placeholder
        return VStack(spacing: 12) {
            Text("Нет данных для предпросмотра")
                .font(.headline)
            Text("Откройте приложение, добавьте блюдо или выполните синхронизацию, затем вернитесь в Preview.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .modelContainer(container)
    }
}
