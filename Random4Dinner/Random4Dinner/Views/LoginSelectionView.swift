import SwiftUI

struct LoginSelectionView: View {
    @AppStorage("loginMode") private var loginMode: String = ""
    var onSelection: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 32) {
            Text("Добро пожаловать!")
                .font(.largeTitle.bold())
                .padding(.top, 40)
            
            Text("Выберите способ входа")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Button(action: {
                loginMode = "google"
                onSelection?()
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
            
            // Зарегистрироваться = Google-авторизация
            Button(action: {
                loginMode = "google" // исправить СЮДА!
                onSelection?()
            }) {
                Label("Зарегистрироваться", systemImage: "person.badge.plus.fill")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Button(action: {
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
    }
}
