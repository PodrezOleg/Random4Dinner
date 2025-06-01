//
//  GoogleAuthManager.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 14.05.25.
//

import Foundation
import GoogleSignIn
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

class GoogleAuthManager: ObservableObject {
    static let shared = GoogleAuthManager()
    private init() {}

    @Published var user: User? = nil // Firebase user

    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    /// Вход через Google + Firebase + регистрация в Firestore
    @MainActor
    func signIn(presenting: UIViewController, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Google Sign-In
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
                guard let idToken = result.user.idToken?.tokenString else {
                    print("❌ Нет idToken для Firebase")
                    completion(false)
                    return
                }
                let accessToken = result.user.accessToken.tokenString
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: accessToken
                )
                // Firebase Auth
                Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                    if let user = authResult?.user, error == nil {
                        DispatchQueue.main.async {
                            self?.user = user
                        }
                        self?.saveUserToFirestore(user)
                        print("✅ Успешно вошли как \(user.email ?? user.uid)")
                        completion(true)
                    } else {
                        print("❌ Firebase Auth Error: \(error?.localizedDescription ?? "Неизвестная ошибка")")
                        completion(false)
                    }
                }
            } catch {
                print("❌ Ошибка входа: \(error)")
                completion(false)
            }
        }
    }

    /// Сохраняем профиль пользователя в Firestore (users/{uid})
    private func saveUserToFirestore(_ user: User) {
        let db = Firestore.firestore()
        let profile: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "photoURL": user.photoURL?.absoluteString ?? ""
        ]
        db.collection("users").document(user.uid).setData(profile, merge: true) { error in
            if let error = error {
                print("❌ Ошибка записи профиля в Firestore: \(error)")
            }
        }
    }

    /// Выход из Firebase и Google
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        self.user = nil
        print("👋 Пользователь вышел")
    }
}
