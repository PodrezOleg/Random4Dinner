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
    
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @AppStorage("loginMode") private var loginMode: String = ""
    
    var isSignedIn: Bool {
        GoogleAuthManager.shared.isSignedIn
    }
    
    var body: some View {
        Group {
            // Экран выбора входа, если режим не выбран
            if loginMode.isEmpty {
                LoginSelectionView()
            }
            // Гостевой режим — только локальная работа, без firebase-групп
            else if loginMode == "guest" {
                NavigationStack {
                    MainContentView(
                        selectedDish: $selectedDish,
                        isAddingDish: $isAddingDish,
                        isShowingList: $isShowingList,
                        errorMessage: $errorMessage
                    )
                }
            }
            // Google/регистрация
            else if loginMode == "google" {
                if !isSignedIn && needsLoginResolver {
                    Color.clear
                } else {
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
        }
        .modifier(AppLifecycleModifier(errorMessage: $errorMessage))
        .onAppear {
            if loginMode == "google" && !isSignedIn {
                needsLoginResolver = true
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            if !isConnected {
                NotificationCenterService.shared.showWarning("Нет подключения к интернету")
            }
        }
    }
}
