//
//  SettingsView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.05.25.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var groupStore: GroupStore
    @State private var showGroups = false
    @State private var showRecipes = false
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Команды")) {
                    Button {
                        showGroups = true
                    } label: {
                        HStack {
                            Image(systemName: "person.3.fill")
                            Text("Мои группы")
                        }
                    }
                }
                
                Section(header: Text("Аккаунт")) {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Выйти из группы")
                        }
                    }
                }
                
                Section(header: Text("Рецепты")) {
                    Button {
                        showRecipes = true
                    } label: {
                        HStack {
                            Image(systemName: "book.closed.fill")
                            Text("Мои рецепты")
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
            .sheet(isPresented: $showGroups) {
                GroupSelectionView()
                    .environmentObject(groupStore)
            }
            .sheet(isPresented: $showRecipes) {
                MyRecipesView() // Реализуй отдельно
            }
            .alert("Вы действительно хотите выйти из группы?", isPresented: $showLogoutAlert) {
                Button("Выйти", role: .destructive) {
                    groupStore.selectedGroup = nil
                }
                Button("Отмена", role: .cancel) { }
            }
        }
    }
}
