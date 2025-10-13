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
        // Читаем clientID из Info.plist (ключ GIDClientID), чтобы не было рассинхронизации
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            #if DEBUG
            print("[AppServicesManager] Google Sign-In configured with clientID from Info.plist")
            #endif
        } else {
            // Фолбэк: если по какой-то причине ключ не найден — логируем предупреждение
            assertionFailure("[AppServicesManager] GIDClientID not found in Info.plist. Please add the key and value.")
            #if DEBUG
            print("[AppServicesManager] Warning: GIDClientID missing in Info.plist. Google Sign-In may not work.")
            #endif
        }
    }
}
