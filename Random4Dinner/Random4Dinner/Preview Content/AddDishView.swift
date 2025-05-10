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
    @State private var selectedCategory: MealCategory = .lunch

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Название")) {
                    TextField("Введите название", text: $name)
                }

                Section(header: Text("Описание")) {
                    TextEditor(text: $about)
                        .frame(height: 150)
                        .multilineTextAlignment(.leading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                }

                Section(header: Text("Категория")) {
                    Picker("Категория", selection: $selectedCategory) {
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

                    if let data = imageData, let uiImage = UIImage(data: data) {
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
                        imageData = data
                    }
                }
            }
            .navigationTitle("Новое блюдо")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        let newDish = Dish(
                            name: name,
                            about: about,
                            imageBase64: imageData?.base64EncodedString(),
                            category: selectedCategory
                        )
                        context.insert(newDish)
                        try? context.save()
                        Task {
                            await DishSyncService.shared.exportDishesToJSON(context: context)
                        }
                        dismiss()
                    }
                    .disabled(name.isEmpty || about.isEmpty)
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
