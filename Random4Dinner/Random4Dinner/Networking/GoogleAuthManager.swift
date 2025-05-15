//
//  GoogleAuthManager.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 14.05.25.
//

import Foundation
import GoogleSignIn
import GoogleSignInSwift
import GoogleAPIClientForRESTCore

class GoogleAuthManager: ObservableObject {
    static let shared = GoogleAuthManager()
    private init() {}

    @Published var user: GIDGoogleUser? = nil

    var isSignedIn: Bool {
        GIDSignIn.sharedInstance.currentUser != nil
    }

    var authorizer: GTMSessionFetcherAuthorizer? {
        GIDSignIn.sharedInstance.currentUser?.fetcherAuthorizer as? GTMSessionFetcherAuthorizer
    }
    
    @MainActor
    func signIn(presenting: UIViewController, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presenting,
                    hint: nil,
                    additionalScopes: ["https://www.googleapis.com/auth/drive.file"]
                )
                self.user = result.user
                print("✅ Вошли как \(result.user.profile?.email ?? "")")
                completion(true)
            } catch {
                print("❌ Ошибка входа: \(error)")
                completion(false)
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        self.user = nil
        print("👋 Пользователь вышел")
    }
}
