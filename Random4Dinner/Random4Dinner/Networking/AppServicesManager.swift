//
//  AppServicesManager.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 23.05.25.
//


import Foundation
import GoogleSignIn

final class AppServicesManager {
    static let shared = AppServicesManager()

    private init() {}

    func configure() {
        // Только инициализация Google Sign-In!
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "336346687083-pl7ar4iqupk08hjue4mlbkfijd1b0ae9.apps.googleusercontent.com"
        )
    }
}
