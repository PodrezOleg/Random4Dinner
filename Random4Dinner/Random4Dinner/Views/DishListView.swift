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
    
    @State private var isLoading = false
    
    private var userId: String? { Auth.auth().currentUser?.uid }
    private var groupId: String? { groupStore.selectedGroup?.id }
    
    private var uniqueDishes: [Dish] {
        var seen = Set<UUID>()
        return allDishes.filter { dish in
            let isMine = dish.userId == userId && (dish.groupId == nil || dish.groupId?.isEmpty == true)
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
                
                if isLoading {
                    ProgressView("Загрузка блюд...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(uniqueDishes) { dish in
                            DishRowView(dish: dish)
                        }
                        .onDelete { indexSet in
                            let dishesToDelete = indexSet.map { uniqueDishes[$0] }
                            Task {
                                await MainActor.run {
                                    for dish in dishesToDelete {
                                        context.delete(dish)
                                    }
                                    try? context.save()
                                }
                                for dish in dishesToDelete {
                                    try? await DishSyncService.shared.deleteDishFromFirestore(dish)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Мои блюда")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: AddDishView()) {
                        Image(systemName: "plus")
                    }
                }
            }
            //            .task {
            //                isLoading = true
            //                try? await DishSyncService.shared.syncDishes(context: context, userGroups: groupStore.groups.map { $0.id })
            //                isLoading = false
            //            }
            //            .onDisappear {
            //                Task {
            //                    try? await DishSyncService.shared.syncDishes(context: context, userGroups: groupStore.groups.map { $0.id })
            //                }
            //            }
        }
    }
    
    
    // MARK: - DishRowView
    struct DishRowView: View {
        let dish: Dish
        var body: some View {
            NavigationLink(destination: DishDetailView(dish: dish)) {
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
}
