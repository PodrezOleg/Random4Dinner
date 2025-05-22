//
//  FirebaseManager.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 23.05.25.
//

import Foundation
import FirebaseCore

final class FirebaseManager {
    static let shared = FirebaseManager()

    private init() {}

    func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
}
