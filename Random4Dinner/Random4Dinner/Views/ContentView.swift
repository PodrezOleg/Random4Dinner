//  ContentView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var groupStore: GroupStore
    @Query private var dishes: [Dish]

    @State private var errorMessage: String? = nil
    @State private var needsLoginResolver = false

    @State private var selectedDish: Dish?
    @State private var isAddingDish = false
    @State private var isShowingList = false

    var isSignedIn: Bool {
        GoogleAuthManager.shared.isSignedIn
    }

    var body: some View {
        ZStack {
            // ⬇️ Логин-пустышка, чтобы блокировать контент, пока нет логина
            if !isSignedIn && needsLoginResolver {
                Color.clear
            } else {
                // ⬇️ Нет выбранной группы? Покажи GroupSelectionView
                if groupStore.selectedGroup == nil {
                    GroupSelectionView()
                        .environmentObject(groupStore)
                } else {
                    NavigationStack {
                        MainContentView(
                            selectedDish: $selectedDish,
                            isAddingDish: $isAddingDish,
                            isShowingList: $isShowingList,
                            errorMessage: $errorMessage
                        )
                    }
                }
            }
        }
        .modifier(AppLifecycleModifier(errorMessage: $errorMessage))
        .onAppear {
            if !isSignedIn {
                needsLoginResolver = true
            }
        }
    }
}
