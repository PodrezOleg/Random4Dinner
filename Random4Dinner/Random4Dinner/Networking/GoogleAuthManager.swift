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
        return GIDSignIn.sharedInstance.currentUser != nil
    }

    var authorizer: GTMFetcherAuthorizationProtocol? {
        return GIDSignIn.sharedInstance.currentUser?.fetcherAuthorizer
    }

    func signIn(presenting: UIViewController, completion: @escaping (Bool) -> Void) {

        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
                self.user = result.user
                print("✅ Пользователь вошёл: \(result.user.profile?.email ?? "")")
                completion(true)
            } catch {
                print("❌ Ошибка входа: \(error.localizedDescription)")
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
