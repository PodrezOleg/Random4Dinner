
//  EditRecipeView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.05.25.
//

import SwiftUI
import SwiftData
import FirebaseAuth


struct EditRecipeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    // Добавляем доступ к текущему пользователю
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    var recipe: Recipe?

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: RecipeCategory = .dessert
    @State private var url: String = ""
    @State private var servings: Int = 12
    @State private var ingredients: [Ingredient] = []
    @State private var recalculatedServings: Int = 12
    @State private var showIngredients = false

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        _title = State(initialValue: recipe?.title ?? "")
        _description = State(initialValue: recipe?.recipeDescription ?? "")
        _category = State(initialValue: recipe?.category ?? .dessert)
        _url = State(initialValue: recipe?.url ?? "")
        _servings = State(initialValue: recipe?.servings ?? 12)
        _ingredients = State(initialValue: recipe?.ingredients ?? [])
        _recalculatedServings = State(initialValue: recipe?.servings ?? 12)
    }

    var body: some View {
        let units = ["г", "мл", "шт", "ст. л.", "ч. л.", "чашка", "щепотка", "по вкусу"]
        NavigationView {
            Form {
                Section(header: Text("Название")) {
                    TextField("Название", text: $title)
                }
                Section(header: Text("Категория")) {
                    Picker("Категория", selection: $category) {
                        ForEach(RecipeCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section(header: Text("Описание")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                Section(header: Text("Ссылка (YouTube, блог и т.д.)")) {
                    TextField("https://...", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                Section(header: Text("Порции")) {
                    Stepper(value: $servings, in: 1...100) {
                        Text("\(servings) порций")
                    }
                }
                Section {
                    DisclosureGroup(isExpanded: $showIngredients) {
                        ForEach($ingredients) { $ingredient in
                            HStack(spacing: 8) {
                                TextField("Название", text: $ingredient.name)
                                    .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                                HStack(spacing: 0) {
                                    TextField("Кол-во", value: $ingredient.amount, formatter: NumberFormatter())
                                        .keyboardType(.decimalPad)
                                        .frame(width: 55, alignment: .trailing)
                                    Picker("", selection: $ingredient.unit) {
                                        ForEach(units, id: \.self) { unit in
                                            Text(unit).tag(unit)
                                        }
                                    }
                                    .frame(width: 48, alignment: .leading)
                                    .pickerStyle(MenuPickerStyle())
                                    .labelsHidden()
                                }
                            }
                        }
                        .onDelete { offsets in
                            ingredients.remove(atOffsets: offsets)
                        }
                        Button("Добавить ингредиент") {
                            ingredients.append(Ingredient(name: "", amount: 0, unit: "г"))
                        }
                    } label: {
                        Label("Ингредиенты", systemImage: "cart")
                            .font(.headline)
                    }
                }
                Section(header: Text("Рассчитать пропорции")) {
                    Stepper(value: $recalculatedServings, in: 1...100) {
                        Text("\(recalculatedServings) порций (предпросмотр)")
                    }
                    ForEach(ingredients) { ingredient in
                        let ratio = Double(recalculatedServings) / Double(servings)
                        let recalculated = ingredient.amount * ratio
                        Text("\(ingredient.name): \(recalculated, specifier: "%.1f") \(ingredient.unit)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(recipe == nil ? "Новый рецепт" : "Редактировать рецепт")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(recipe == nil ? "Добавить" : "Сохранить") {
                        saveRecipe()    // без второго dismiss()
                    }
                    .disabled(title.isEmpty || description.isEmpty || ingredients.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private func saveRecipe() {
        if let recipe = recipe {
            // обновление
            recipe.title = title
            recipe.recipeDescription = description
            recipe.category = category
            recipe.url = url
            recipe.ingredients = ingredients
            recipe.servings = servings
            recipe.lastModified = Date()
            recipe.isSync = false
        } else {
            // создание
            let newRecipe = Recipe(
                title: title,
                description: description,
                category: category,
                url: url,
                createdAt: Date(),
                ingredients: ingredients,
                servings: servings,
                userId: currentUserId,
                isSync: false,
                lastModified: Date()
            )
            context.insert(newRecipe)
        }

        try? context.save()

        // ✅ Асинхронный вызов синхронизации без изменения сигнатуры функции
        if let userId = currentUserId {
            Task { @MainActor in
                await RecipeSyncService.shared.syncRecipes(context: context, userId: userId)
            }
        }

        // Закрываем экран один раз
        dismiss()
    }
}
