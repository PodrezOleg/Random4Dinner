//
//  AddDishView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import PhotosUI

struct AddDishView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var about = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Название")) {
                    TextField("Введите название", text: $name)
                }
                
                Section(header: Text("Описание")) {
                    TextEditor(text: $about)
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
                    if let imageData = imageData, let uiImage = UIImage(data: imageData) {
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
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
            .navigationTitle("Новое блюдо")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        let newDish = Dish(name: name, about: about, image: imageData)
                        context.insert(newDish)
                        dismiss()
                    }
                    .disabled(name.isEmpty || about.isEmpty) // Блокируем, если пустые поля
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
}
