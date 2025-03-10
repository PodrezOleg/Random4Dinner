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
                    TextField("Введите описание", text: $about)
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
