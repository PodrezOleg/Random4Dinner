//
//  DishListView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct DishListView: View {
    @EnvironmentObject var groupStore: GroupStore
    @Environment(\.modelContext) private var context
    @Query private var allDishes: [Dish]

    private var userId: String? { Auth.auth().currentUser?.uid }
    private var groupId: String? { groupStore.selectedGroup?.id }

    private var uniqueDishes: [Dish] {
        var seen = Set<UUID>()
        return allDishes.filter { dish in
            let isMine = dish.userId == userId && dish.groupId == nil
            let isGroup = groupId != nil && dish.groupId == groupId
            return (isMine || isGroup) && seen.insert(dish.id).inserted
        }
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if let group = groupStore.selectedGroup {
                    Text("Группа: \(group.name)")
                        .font(.headline)
                        .padding(.leading)
                } else {
                    Text("Личные блюда")
                        .font(.headline)
                        .padding(.leading)
                }
                List {
                    ForEach(uniqueDishes) { dish in
                        DishRowView(dish: dish)
                    }
                    .onDelete { indexSet in
                        let dishesToDelete = indexSet.map { uniqueDishes[$0] }
                        Task {
                            // 1. Удаляем из локальной базы (MainActor)
                            await MainActor.run {
                                for dish in dishesToDelete {
                                    context.delete(dish)
                                }
                                try? context.save()
                            }
                            // 2. Удаляем из Firestore
                            for dish in dishesToDelete {
                                try? await DishSyncService.shared.deleteDishFromFirestore(dish)
                            }
                            // 3. Пересинхронизируем (только на MainActor!)
                            await MainActor.run {
                                Task {
                                    try? await DishSyncService.shared.syncDishes(context: context, userGroups: groupStore.groups.map { $0.id })
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Мои блюда")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: AddDishView()) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                try? await DishSyncService.shared.syncDishes(context: context, userGroups: groupStore.groups.map { $0.id })
            }
            .onDisappear {
                Task {
                    try? await DishSyncService.shared.syncDishes(context: context, userGroups: groupStore.groups.map { $0.id })
                }
            }
        }
    }
}

// MARK: - DishRowView
struct DishRowView: View {
    let dish: Dish
    var body: some View {
        NavigationLink(destination: DishDetailView(dish: dish)) {
            HStack {
                DishImageView(imageData: Data(base64Encoded: dish.imageBase64 ?? ""))
                VStack(alignment: .leading) {
                    Text(dish.name)
                        .font(.headline)
                    Text(dish.about)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - DishImageView
struct DishImageView: View {
    let imageData: Data?
    var body: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: "photo")
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .foregroundColor(.gray)
                .opacity(0.5)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
