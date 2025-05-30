//
//  EditRecipeView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.05.25.
//

import SwiftUI
import SwiftData

struct EditRecipeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var recipe: Recipe?

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var category: RecipeCategory = .dessert
    @State private var url: String = ""
    @State private var servings: Int = 12
    @State private var ingredients: [Ingredient] = []
    @State private var recalculatedServings: Int = 12

    // <--- Новое состояние для DisclosureGroup
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
                    .pickerStyle(.segmented)
                }
                Section(header: Text("Описание")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .growingTextEditor()
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
                // --- INGREDIENTS AS DISCLOSURE GROUP ---
                Section {
                    DisclosureGroup(isExpanded: $showIngredients) {
                        ForEach($ingredients) { $ingredient in
                            HStack(spacing: 8) {
                                TextField("Название", text: $ingredient.name)
                                    .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                                HStack(spacing: 0) {
                                    TextField("Кол-во", value: $ingredient.amount, formatter: NumberFormatter())
                                        .keyboardType(.decimalPad)
                                        .frame(width: 55, alignment: .trailing)
                                        .padding(.vertical, 6)
                                    Picker("", selection: $ingredient.unit) {
                                        ForEach(units, id: \.self) { unit in
                                            Text(unit).tag(unit)
                                                .minimumScaleFactor(0.5)
                                        }
                                    }
                                    .frame(width: 48, alignment: .leading)
                                    .pickerStyle(MenuPickerStyle())
                                    .labelsHidden()
                                    .padding(.vertical, 6)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { offsets in
                            ingredients.remove(atOffsets: offsets)
                        }
                        Button("Добавить ингредиент") {
                            ingredients.append(Ingredient(name: "", amount: 0, unit: "г"))
                        }
                        .padding(.top, 4)
                    } label: {
                        Label("Ингредиенты", systemImage: "cart")
                            .font(.headline)
                    }
                }
                // --- Preview ---
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
                        saveRecipe()
                        dismiss()
                    }
                    .disabled(title.isEmpty || description.isEmpty || ingredients.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveRecipe() {
        if let recipe = recipe {
            recipe.title = title
            recipe.recipeDescription = description
            recipe.category = category
            recipe.url = url.isEmpty ? nil : url
            recipe.servings = servings
            recipe.ingredients = ingredients
        } else {
            let newRecipe = Recipe(
                title: title,
                description: description,
                category: category,
                url: url.isEmpty ? nil : url,
                ingredients: ingredients,
                servings: servings
            )
            context.insert(newRecipe)
        }
        try? context.save()
    }
}
