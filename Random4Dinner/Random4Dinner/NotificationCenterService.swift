//
//  NotificationCenterService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 10.05.25.
//

import Foundation
import SwiftUI
import Combine

enum AppNotificationType: Equatable {
    case success(String)
    case warning(String)
    case error(String, resolution: String)
    case info(String)
}

struct AppNotification: Identifiable, Equatable {
    let id = UUID()
    let type: AppNotificationType
}

class NotificationCenterService: ObservableObject {
    static let shared = NotificationCenterService()
    
    @Published var currentNotification: AppNotification?

    private init() {}

    func showSuccess(_ message: String) {
        showAutoDismiss(.success(message))
    }

    func showWarning(_ message: String) {
        showAutoDismiss(.warning(message))
    }

    func showInfo(_ message: String) {
        showAutoDismiss(.info(message))
    }

    func showError(_ message: String, resolution: String) {
        currentNotification = AppNotification(type: .error(message, resolution: resolution))
    }

    func dismiss() {
        currentNotification = nil
    }

    private func showAutoDismiss(_ type: AppNotificationType) {
        currentNotification = AppNotification(type: type)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.currentNotification?.type == type {
                self.currentNotification = nil
            }
        }
    }
}
