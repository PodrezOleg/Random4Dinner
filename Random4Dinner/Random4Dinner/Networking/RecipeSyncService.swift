import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftData

extension Notification.Name {
    static let syncSummary = Notification.Name("RecipeSyncSummary")
}

struct RecipeSyncSummary {
    let exported: Int
    let created: Int
    let updated: Int
}

@MainActor
final class RecipeSyncService {
    static let shared = RecipeSyncService()
    private let db = Firestore.firestore()

    /// Основная функция синхронизации рецептов
    func syncRecipes(context: ModelContext, userId: String) async {
        var exportedCount = 0
        var createdCount = 0
        var updatedCount = 0

        do {
            // 1) Экспорт локальных несинхронизированных рецептов
            exportedCount = try await exportLocalChanges(context: context, userId: userId)

            // 2) Импорт с Firestore
            let importResult = try await importFromFirestore(context: context, userId: userId)
            createdCount = importResult.created
            updatedCount = importResult.updated

            // 3) Итог
            print("✅ Экспортировано новых рецептов в Firestore: \(exportedCount)")
            print("✅ Импортировано/обновлено рецептов из Firestore: \(createdCount + updatedCount) (создано: \(createdCount), обновлено: \(updatedCount))")

            // 4) Отправляем уведомление
            let summary = RecipeSyncSummary(exported: exportedCount, created: createdCount, updated: updatedCount)
            NotificationCenter.default.post(name: .syncSummary, object: summary)

        } catch {
            print("❌ Ошибка синхронизации рецептов: \(error.localizedDescription)")
        }
    }

    // MARK: - Экспорт
    private func exportLocalChanges(context: ModelContext, userId: String) async throws -> Int {
        let unsyncedDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { $0.isSync == false }
        )
        let localRecipes = try context.fetch(unsyncedDescriptor)
        var exported = 0

        for recipe in localRecipes {
            recipe.userId = userId
            recipe.lastModified = .now

            try await setRecipeInFirestore(recipe)
            recipe.isSync = true
            exported += 1
        }

        try context.save()
        return exported
    }

    // MARK: - Импорт
    private func importFromFirestore(context: ModelContext, userId: String) async throws -> (created: Int, updated: Int) {
        let snapshot = try await db.collection("recipes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        var createdCount = 0
        var updatedCount = 0

        for document in snapshot.documents {
            let data = document.data()

            guard
                let idString = data["id"] as? String,
                let uuid = UUID(uuidString: idString)
            else { continue }

            let descriptor = FetchDescriptor<Recipe>(
                predicate: #Predicate<Recipe> { $0.id == uuid }
            )

            let remoteLastModified = Self.extractDate(from: data["lastModified"]) ?? .distantPast
            let existing = try context.fetch(descriptor).first

            if let local = existing {
                let localLM = local.lastModified ?? .distantPast
                if localLM < remoteLastModified {
                    updateRecipe(local, with: data)
                    updatedCount += 1
                }
            } else {
                createRecipe(from: data, context: context)
                createdCount += 1
            }
        }

        try context.save()
        return (createdCount, updatedCount)
    }

    // MARK: - Firestore запись
    private func setRecipeInFirestore(_ recipe: Recipe) async throws {
        let payload = recipe.toDictionary()
        try await db.collection("recipes").document(recipe.id.uuidString).setData(payload)
    }

    // MARK: - Helpers
    private static func extractDate(from any: Any?) -> Date? {
        if let seconds = any as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }
        if let ts = any as? Timestamp {
            return ts.dateValue()
        }
        if let s = any as? String, let d = TimeInterval(s) {
            return Date(timeIntervalSince1970: d)
        }
        return nil
    }

    private func updateRecipe(_ recipe: Recipe, with data: [String: Any]) {
        if let title = data["title"] as? String { recipe.title = title }
        if let description = data["description"] as? String { recipe.recipeDescription = description }
        if let categoryRaw = data["category"] as? String,
           let category = RecipeCategory(rawValue: categoryRaw) { recipe.category = category }
        if let url = data["url"] as? String { recipe.url = url }
        if let createdAtAny = data["createdAt"] { recipe.createdAt = Self.extractDate(from: createdAtAny) ?? recipe.createdAt }
        if let lastModifiedAny = data["lastModified"] { recipe.lastModified = Self.extractDate(from: lastModifiedAny) ?? recipe.lastModified }
        if let servings = data["servings"] as? Int { recipe.servings = servings }

        if let raw = data["ingredients"] as? [[String: Any]] {
            recipe.ingredients = raw.compactMap { ing in
                guard
                    let name = ing["name"] as? String,
                    let amount = (ing["amount"] as? NSNumber)?.doubleValue ?? ing["amount"] as? Double,
                    let unit = ing["unit"] as? String
                else { return nil }
                let id = (ing["id"] as? String).flatMap(UUID.init) ?? UUID()
                return Ingredient(id: id, name: name, amount: amount, unit: unit)
            }
        }
        recipe.isSync = true
    }

    private func createRecipe(from data: [String: Any], context: ModelContext) {
        guard
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            let categoryRaw = data["category"] as? String,
            let category = RecipeCategory(rawValue: categoryRaw),
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString)
        else { return }

        let rawIngredients = (data["ingredients"] as? [[String: Any]]) ?? []
        let ingredients: [Ingredient] = rawIngredients.compactMap { ing in
            guard
                let name = ing["name"] as? String,
                let amount = (ing["amount"] as? NSNumber)?.doubleValue ?? ing["amount"] as? Double,
                let unit = ing["unit"] as? String
            else { return nil }
            let ingId = (ing["id"] as? String).flatMap(UUID.init) ?? UUID()
            return Ingredient(id: ingId, name: name, amount: amount, unit: unit)
        }

        let createdAt = Self.extractDate(from: data["createdAt"]) ?? Date()
        let lastModified = Self.extractDate(from: data["lastModified"]) ?? Date()
        let url = data["url"] as? String
        let servings = data["servings"] as? Int ?? 1
        let userId = data["userId"] as? String

        let recipe = Recipe(
            id: id,
            title: title,
            description: description,
            category: category,
            url: url,
            createdAt: createdAt,
            ingredients: ingredients,
            servings: servings,
            userId: userId,
            isSync: true,
            lastModified: lastModified
        )

        context.insert(recipe)
    }

    // MARK: - Удаление рецепта из Firestore
    func deleteRecipeFromFirestore(_ recipe: Recipe) async throws {
        let id = recipe.id.uuidString
        try await db.collection("recipes").document(id).delete()
    }
}
