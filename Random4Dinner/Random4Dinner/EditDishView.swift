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
                TextEditor(text: $dish.about)
                    .frame(height: 150) // Высота поля для ввода текста
                    .multilineTextAlignment(.leading) // Выравнивание текста
                    .cornerRadius(10) // Закруглённые края
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1) // Обводка для эстетики
                    )
            }
                
                Section(header: Text("Фото")) {
                    PhotosPicker(selection: $selectedImage, matching: .images, photoLibrary: .shared()) {
                        Text("Выбрать фото")
                    }
                    // Показываем существующее изображение, если оно есть
                    if let imageData = dish.imageBase64,
                       let data = Data(base64Encoded: imageData),
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    // Показываем новое изображение, если выбрано
                    else if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        .onChange(of: selectedImage) { oldItem, newItem in
            Task {
                // Загружаем изображение и сохраняем в объекте Dish
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
                        // Сохраняем изменения в модели
                        try? context.save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Удалить") {
                        // Удаляем блюдо
                        context.delete(dish)
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }

