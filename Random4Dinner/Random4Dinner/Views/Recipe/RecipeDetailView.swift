//
//  RecipeDetailView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.05.25.
//

import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    @State private var servings: Int
    @State private var showEdit = false

    init(recipe: Recipe) {
        self.recipe = recipe
        _servings = State(initialValue: recipe.servings)
    }

    var body: some View {
           ScrollView {
               VStack(alignment: .leading, spacing: 16) {
                   // Название и кнопка "редактировать"
                   HStack {
                       Text(recipe.title)
                           .font(.title.bold())
                       Spacer()
                       Button(action: {
                           showEdit = true
                       }) {
                           Image(systemName: "pencil")
                               .imageScale(.large)
                       }
                       .accessibilityLabel("Редактировать")
                   }

                   Text(recipe.category.rawValue)
                       .font(.headline)
                       .foregroundColor(.secondary)

                // Stepper для порций
                Stepper("Порции: \(servings)", value: $servings, in: 1...100)

                // Ингредиенты
                if !recipe.ingredients.isEmpty {
                    let ratio = Double(servings) / Double(recipe.servings)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ингредиенты:")
                            .font(.headline)
                        ForEach(recipe.ingredients, id: \.id) { ingredient in
                            HStack {
                                Text(ingredient.name).bold()
                                Spacer()
                                Text("\((ingredient.amount * ratio).clean) \(ingredient.unit)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Инструкция
                if !recipe.recipeDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Инструкция:")
                            .font(.headline)
                        Text(recipe.recipeDescription)
                            .font(.body)
                    }
                }

                // Ссылка
                if let url = recipe.url, !url.isEmpty {
                    Link("Смотреть видео/сайт", destination: URL(string: url)!)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Редактировать") {
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditRecipeView(recipe: recipe)
        }
    }
}

// Округление числа
extension Double {
    var clean: String {
        self.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", self)
        : String(format: "%.1f", self)
    }
}
