//
//  AppDelegate.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.05.25.
//

import UIKit
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Task {
            do {
                let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                GoogleAuthManager.shared.user = user
                print("🔁 Восстановили предыдущий вход: \(user.profile?.email ?? "")")
            } catch {
                print("⚠️ Нет сохранённой сессии: \(error)")
            }
        }
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
