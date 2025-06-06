//
//  AppDelegate.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.05.25.
//

//
//  AppDelegate.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.05.25.
//

import UIKit
import GoogleSignIn
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
