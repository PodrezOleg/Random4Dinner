import SwiftUI
import SwiftData
import FirebaseAuth

struct AppLifecycleModifier: ViewModifier {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var groupStore: GroupStore
    @Query private var dishes: [Dish]
    @Binding var errorMessage: String?
    @State private var needsLoginResolver = false
    @AppStorage("loginMode") private var loginMode: String = ""
    
    func body(content: Content) -> some View {
        content
            .background(loginResolverView)
            .onAppear {
                if loginMode == "google" && !GoogleAuthManager.shared.isSignedIn {
                    needsLoginResolver = true
                } else if loginMode == "google" {
                    updateGroupsAndSync()
                }
            }
            .onChange(of: dishes, initial: false) { _, _ in
                if loginMode == "google" {
                    updateGroupsAndSync()
                }
            }
            .onChange(of: UIApplication.shared.connectedScenes.first?.activationState, initial: false) { _, newPhase in
                if loginMode == "google" && newPhase == .background {
                    updateGroupsAndSync()
                }
            }
    }

    @ViewBuilder
    private var loginResolverView: some View {
        if needsLoginResolver {
            ViewControllerResolver { controller in
                GoogleAuthManager.shared.signIn(presenting: controller) { success in
                    needsLoginResolver = false
                    if success {
                        updateGroupsAndSync()
                    } else {
                        errorMessage = "Не удалось войти в Google"
                    }
                }
            }
            .frame(width: 0, height: 0)
        }
    }

    private func updateGroupsAndSync() {
        guard let userId = Auth.auth().currentUser?.uid, loginMode == "google" else { return }
        groupStore.fetchGroups(for: userId) {
            Task { @MainActor in
                do {
                    try await DishSyncService.shared.syncDishes(context: context, userGroups: groupStore.groups.map { $0.id })
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
