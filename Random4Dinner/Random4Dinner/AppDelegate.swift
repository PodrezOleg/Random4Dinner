//
//  AppDelegate.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.05.25.
//

import UIKit
import GoogleSignIn
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Восстановить пользователя из Firebase (если есть)
        if let firebaseUser = Auth.auth().currentUser {
            GoogleAuthManager.shared.user = firebaseUser
            print("🔁 Восстановили предыдущий Firebase вход: \(firebaseUser.email ?? firebaseUser.uid)")
        } else {
            print("⚠️ Нет сохранённой Firebase-сессии")
        }
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
