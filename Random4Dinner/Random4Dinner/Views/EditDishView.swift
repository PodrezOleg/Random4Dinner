//
//  EditDishView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import PhotosUI
import FirebaseAuth

struct EditDishView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var dish: Dish
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?

    private var userId: String? { Auth.auth().currentUser?.uid }
    private var groupId: String? { dish.groupId }

    var body: some View {
        Form {
            Section(header: Text("Название")) {
                TextField("Введите название", text: $dish.name)
            }

            Section(header: Text("Описание")) {
                TextEditor(text: $dish.about)
                    .frame(height: 150)
                    .multilineTextAlignment(.leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
            }

            Section(header: Text("Категория")) {
                Picker("Категория", selection: $dish.category) {
                    ForEach(MealCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section(header: Text("Фото")) {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Text("Выбрать фото")
                }

                if let base64 = dish.imageBase64,
                   let data = Data(base64Encoded: base64),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let data = imageData,
                          let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .onChange(of: selectedImage) { _, newItem in
            Task {
                if let newItem, let data = try? await newItem.loadTransferable(type: Data.self) {
                    dish.imageBase64 = data.base64EncodedString()
                    imageData = data
                }
            }
        }
        .navigationTitle("Редактировать блюдо")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Сохранить") {
                    Task {
                        // 1. Сохраняем локально на MainActor и закрываем экран
                        await MainActor.run {
                            try? context.save()
                            dismiss()
                        }
                        // 2. Пробуем синхронизировать изменения с Firestore
                        guard let userId = userId else { return }
                        let decoded = DishDECOD(
                            id: dish.id,
                            name: dish.name,
                            about: dish.about,
                            imageBase64: dish.imageBase64,
                            category: dish.category ?? .lunch,
                            userId: userId,
                            groupId: groupId
                        )
                        do {
                            try await DishSyncService.shared.addOrUpdateDish(decoded, context: context)
                        } catch {
                            await MainActor.run {
                                NotificationCenterService.shared.showError(
                                    "Ошибка синхронизации изменений",
                                    resolution: "Проверьте интернет — изменения сохранены локально"
                                )
                            }
                            print("Ошибка при сохранении: \(error)")
                        }
                    }
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                Button("Удалить") {
                    Task {
                        // 1. Удаляем локально и сразу закрываем
                        await MainActor.run {
                            context.delete(dish)
                            try? context.save()
                            dismiss()
                        }
                        // 2. Пробуем удалить из облака
                        do {
                            try await DishSyncService.shared.deleteDishFromFirestore(dish)
                        } catch {
                            await MainActor.run {
                                NotificationCenterService.shared.showError(
                                    "Ошибка удаления из облака",
                                    resolution: "Проверьте интернет — блюдо удалено локально"
                                )
                            }
                            print("Ошибка удаления блюда: \(error)")
                        }
                    }
                }
                .foregroundColor(.red)
            }
        }
    }
}
