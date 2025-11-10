//
//  DishListView.swift
//  Random4Dinner
//
//  Created by Oleg Подрез on 11.03.25.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct DishListView: View {
    @EnvironmentObject var groupStore: GroupStore
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Dish.name, order: .forward)]) private var allDishes: [Dish]

    private var userId: String? { Auth.auth().currentUser?.uid }
    private var groupId: String? { groupStore.selectedGroup?.id }

    /// Локальный отбор с дедупликацией
    private var uniqueDishes: [Dish] {
        var seen = Set<UUID>()
        return allDishes.filter { dish in
            // Личные (включая "старые" без userId)
            let isPersonal = (dish.groupId == nil) && (dish.userId == userId || dish.userId == nil)
            // Групповые — для выбранной группы
            let isGroup = (groupId != nil) && (dish.groupId == groupId)
            // Дедуп по UUID
            let isNew = seen.insert(dish.id).inserted
            return (isPersonal || isGroup) && isNew
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                BackgroundView().ignoresSafeArea()

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

                            // 1) Снимки на MainActor, пока объекты «живые»
                            let snapshots: [DishDTO] = dishesToDelete.map { $0.snapshotDTO() }

                            // 2) Мгновенно обновляем локальный источник данных (MainActor, без async)
                            withAnimation {
                                for dish in dishesToDelete {
                                    context.delete(dish)
                                }
                                try? context.save()
                            }

                            // 3) Удаляем в Firestore в фоне (DTO -> модель, если сервис пока ждёт Dish)
                            Task {
                                for dto in snapshots {
                                    try? await DishSyncService.shared.deleteDishFromFirestore(dto.toModel())
                                }
                            }
                        }
                    }
                    .overlay {
//                        if uniqueDishes.isEmpty {
//                            RandomButton
//                            VStack(spacing: 12) {
//                                Text("Здесь пока пусто")
//                                    .font(.headline)
//                                    .foregroundColor(.secondary)
//                                Text("Добавьте личное блюдо или выберите группу")
//                                    .font(.subheadline)
//                                    .foregroundColor(.secondary)
//                                NavigationLink(destination: AddDishView()) {
//                                    Label("Добавить блюдо", systemImage: "plus")
//                                }
//                                .buttonStyle(.borderedProminent)
//                            }
//                            .padding()
//                        }
                    }
                    .listStyle(.inset)
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
                    try? await DishSyncService.shared.syncDishes(context: context,
                                                                 userGroups: groupStore.groups.map { $0.id })
                }
                .onDisappear {
                    Task {
                        try? await DishSyncService.shared.syncDishes(context: context,
                                                                     userGroups: groupStore.groups.map { $0.id })
                    }
                }
            }
        }
    }
}

// MARK: - DishRowView
struct DishRowView: View {
    let dish: Dish

    var body: some View {
        NavigationLink(destination: DishDetailView(dishId: dish.id)) {
            HStack {
                if let urlString = dish.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .failure(_):
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFill()
                                .foregroundColor(.gray)
                                .opacity(0.5)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
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

                VStack(alignment: .leading) {
                    Text(dish.name).font(.headline)
                    Text(dish.about)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
