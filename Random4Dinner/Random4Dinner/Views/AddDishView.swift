//
//  AddDishView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import PhotosUI
import FirebaseAuth

struct AddDishView: View {
    @EnvironmentObject var groupStore: GroupStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    private var groupId: String? { groupStore.selectedGroup?.id }
    private var userId: String? { Auth.auth().currentUser?.uid }
    
    @State private var name = ""
    @State private var about = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var selectedCategory: MealCategory = .lunch
    
    private var formContent: some View {
        Form {
            Section(header: Text("Название")) {
                TextField("Введите название", text: $name)
            }
            
            Section(header: Text("Описание")) {
                TextEditor(text: $about)
                    .frame(height: 150)
                    .growingTextEditor()
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
    }
    
    var body: some View {
        NavigationView {
            formContent
                .onChange(of: selectedImage) { _, newItem in
                    Task {
                        if let newItem, let data = try? await newItem.loadTransferable(type: Data.self) {
                            imageData = data
                        }
                    }
                }
                .navigationTitle("Новое блюдо")
                .toolbar {
                    saveButton
                    cancelButton
                }
        }
    }
    
    private var saveButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Сохранить") {
                guard let userId = userId else { return }
                let newDishDecoded = DishDECOD(
                    id: UUID(),
                    name: name,
                    about: about,
                    imageBase64: imageData?.base64EncodedString(),
                    category: selectedCategory,
                    userId: userId,
                    groupId: groupId
                )
                Task {
                    do {
                        // 1. Сохрани локально и сразу закрой экран (MainActor)
                        await MainActor.run {
                            let dish = Dish(from: newDishDecoded)
                            context.insert(dish)
                            try? context.save()
                            dismiss() // Экран закрываем сразу!
                        }
                        // 2. Пробуй синхронизировать с Firestore (можно не ждать)
                        try await DishSyncService.shared.addOrUpdateDish(newDishDecoded, context: context)
                    } catch {
                        await MainActor.run {
                            NotificationCenterService.shared.showError(
                                "Ошибка синхронизации с облаком",
                                resolution: "Проверьте интернет — данные локально сохранены"
                            )
                        }
                        print("Ошибка сохранения блюда: \(error)")
                    }
                }
            }
            .disabled(name.isEmpty || about.isEmpty)
        }
    }
    
    private var cancelButton: some ToolbarContent {
         ToolbarItem(placement: .topBarLeading) {
             Button("Отмена") {
                 dismiss()
             }
         }
     }
 }
