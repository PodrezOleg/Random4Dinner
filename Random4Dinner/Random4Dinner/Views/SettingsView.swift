import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var groupStore: GroupStore
    @AppStorage("loginMode") private var loginMode: String = ""
    @State private var showGroups = false
    @State private var showRecipes = false
    @State private var showLogoutAlert = false
    
    var body: some View {
      
        NavigationView {
        
            ZStack {
                BackgroundView()
                List {
                    // Секция "Команды" только для Google-режима
                    if loginMode == "google" {
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
                    }
                    
                    Section(header: Text("Аккаунт")) {
                        Button(role: .destructive) {
                            showLogoutAlert = true
                        }
                        label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Выйти из аккаунта")
                            }
                            
                        }
                        .buttonStyle(.glass(.clear))
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
                    .buttonStyle(.glass(.clear))
                }
                .navigationTitle("Настройки")
                .sheet(isPresented: $showGroups) {
                    GroupSelectionView()
                        .environmentObject(groupStore)
                }
                .sheet(isPresented: $showRecipes) {
                    MyRecipesView()
                }
                .alert("Вы действительно хотите выйти?", isPresented: $showLogoutAlert) {
                    Button("Выйти", role: .destructive) {
                        loginMode = ""
                    }
                    Button("Отмена", role: .cancel) { }
                }
            }
    
        }
    }
}
#Preview {
    SettingsView()
        .environmentObject(GroupStore())
}
