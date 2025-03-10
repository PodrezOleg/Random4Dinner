//
//  EditDishView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import PhotosUI

struct EditDishView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var dish: Dish
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        Form {
            Section(header: Text("Название")) {
                TextField("Введите название", text: $dish.name)
            }

            Section(header: Text("Описание")) {
                TextField("Введите описание", text: $dish.about)
            }

            Section(header: Text("Фото")) {
                PhotosPicker(selection: $selectedImage, matching: .images, photoLibrary: .shared()) {
                    Text("Выбрать фото")
                }
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .onChange(of: selectedImage) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    dish.image = data
                }
            }
        }
        .navigationTitle("Редактировать блюдо")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Сохранить") {
                    try? context.save() // Сохраняем изменения
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Удалить") {
                    context.delete(dish) // Удаляем блюдо
                    dismiss()
                }
                .foregroundColor(.red)
            }
        }
    }
}
