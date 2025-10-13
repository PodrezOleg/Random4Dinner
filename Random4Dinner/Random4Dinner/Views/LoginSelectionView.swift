import SwiftUI
import FirebaseAuth

struct LoginSelectionView: View {
    @AppStorage("loginMode") private var loginMode: String = ""
    var onSelection: (() -> Void)? = nil

    @EnvironmentObject private var groupStore: GroupStore
    @Environment(\.modelContext) private var context

    @State private var presentResolver = false
    @State private var isSigningIn = false
    @State private var signInError: String?

    var body: some View {
        VStack(spacing: 32) {
            Text("Добро пожаловать!")
                .font(.largeTitle.bold())
                .padding(.top, 40)
            
            Text("Выберите способ входа")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Button(action: {
                startGoogleSignInFlow()
            }) {
                Label("Войти через Google", systemImage: "person.fill.checkmark")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(isSigningIn)

            if isSigningIn {
                ProgressView("Вход через Google...")
            }
            if let signInError = signInError {
                Text(signInError)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                // Явный вход как гость
                loginMode = "guest"
                onSelection?()
            }) {
                Label("Продолжить без регистрации", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: 350)
        // Презентуем resolver только когда нужно показать Google UI
        .background(
            Group {
                if presentResolver {
                    ViewControllerResolver { vc in
                        presentResolver = false
                        performGoogleSignIn(presentingVC: vc)
                    }
                    .frame(width: 0, height: 0)
                }
            }
        )
    }

    private func startGoogleSignInFlow() {
        signInError = nil
        isSigningIn = true
        presentResolver = true
    }

    private func performGoogleSignIn(presentingVC: UIViewController) {
        GoogleAuthManager.shared.signIn(presenting: presentingVC) { success in
            if success {
                // Успешный вход -> грузим группы и блюда
                let uid = Auth.auth().currentUser?.uid ?? ""
                groupStore.fetchGroups(for: uid) {
                    Task {
                        let groupIds = groupStore.groups.map { $0.id }
                        do {
                            try await DishSyncService.shared.syncDishes(context: context, userGroups: groupIds)
                        } catch {
                            // Не блокируем вход — просто уведомим
                            await MainActor.run {
                                signInError = "Не удалось синхронизировать блюда. Данные будут доступны оффлайн."
                            }
                        }
                        await MainActor.run {
                            loginMode = "google"
                            isSigningIn = false
                            onSelection?()
                        }
                    }
                }
            } else {
                // Пользователь отменил или ошибка — заходим как гость автоматически
                DispatchQueue.main.async {
                    isSigningIn = false
                    signInError = nil // можно оставить пустым, чтобы не пугать
                    loginMode = "guest"
                    onSelection?()
                }
            }
        }
    }
}
