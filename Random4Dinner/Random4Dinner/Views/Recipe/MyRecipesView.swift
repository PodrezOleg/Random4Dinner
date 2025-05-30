//
//  MyRecipesView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.05.25.
//

import SwiftUI
import SwiftData

struct MyRecipesView: View {
    @Environment(\.modelContext) private var context
    @Query private var recipes: [Recipe]
    @State private var searchText = ""
    @State private var showAddRecipe = false
    @State private var selectedRecipe: Recipe?
    
    // Фильтрация
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
        NavigationView {
            List {
                ForEach(filteredRecipes) { recipe in
                    RecipeRowView(recipe: recipe)
                        .onTapGesture {
                            selectedRecipe = recipe
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
            .sheet(item: $selectedRecipe) { recipe in
                EditRecipeView(recipe: recipe)
            }
            .sheet(isPresented: $showAddRecipe) {
                EditRecipeView()
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

struct RecipeRowView: View {
    let recipe: Recipe
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .font(.headline)
                Text(recipe.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let url = recipe.url, !url.isEmpty {
                Link(destination: URL(string: url)!) {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
