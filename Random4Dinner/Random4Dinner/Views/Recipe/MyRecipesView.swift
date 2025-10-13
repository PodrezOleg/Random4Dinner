//
//  MyRecipesView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.05.25.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct MyRecipesView: View {
    @Environment(\.modelContext) private var context
    @Query private var recipes: [Recipe]
    @State private var searchText = ""
    @State private var showAddRecipe = false
    // Раньше: @State private var selectedRecipe: Recipe?
    @State private var selectedRecipeId: UUID?

    // Получаем текущего пользователя
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return recipes
        } else {
            return recipes.filter { recipe in
                recipe.title.localizedCaseInsensitiveContains(searchText) ||
                recipe.recipeDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredRecipes) { recipe in
                    Button {
                        selectedRecipeId = recipe.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(recipe.title)
                                    .font(.headline)
                                Text(recipe.category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск по названию или ингредиенту")
            .navigationTitle("Мои рецепты")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddRecipe = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Раньше показывали sheet(item: $selectedRecipe)
            .navigationDestination(item: $selectedRecipeId) { recipeId in
                RecipeDetailView(recipeId: recipeId)
            }
            .sheet(isPresented: $showAddRecipe) {
                EditRecipeView()
            }
        }
        .onAppear {
            if recipes.isEmpty {
                // Пример добавления тестовых рецептов
                let testIngredients = [
                    Ingredient(name: "Яйцо", amount: 2, unit: "шт"),
                    Ingredient(name: "Мука", amount: 150, unit: "г"),
                    Ingredient(name: "Сахар", amount: 100, unit: "г")
                ]
                let testRecipe = Recipe(
                    title: "Блины",
                    description: "Смешать все ингредиенты и жарить на сковороде.",
                    category: .pie,
                    ingredients: testIngredients,
                    servings: 4
                )
                context.insert(testRecipe)
                try? context.save()
            }
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets {
            let recipe = filteredRecipes[index]
            context.delete(recipe)
        }
        try? context.save()
    }
}

#Preview {
    MyRecipesView()
}

