//
//  NotificationCenterService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 10.05.25.
//

import Foundation
import SwiftUI
import Combine

/// Тип уведомления
enum AppNotificationType: Equatable {
    case success(String)
    case warning(String)
    case error(String, resolution: String)
}

/// Модель уведомления
struct AppNotification: Identifiable, Equatable {
    let id = UUID()
    let type: AppNotificationType
}

/// ViewModel, который можно внедрить в любую View
class NotificationCenterService: ObservableObject {
    static let shared = NotificationCenterService()
    
    @Published var currentNotification: AppNotification?

    private init() {}

    func showSuccess(_ message: String) {
        currentNotification = AppNotification(type: .success(message))
    }

    func showWarning(_ message: String) {
        currentNotification = AppNotification(type: .warning(message))
    }

    func showError(_ message: String, resolution: String) {
        currentNotification = AppNotification(type: .error(message, resolution: resolution))
    }

    func dismiss() {
        currentNotification = nil
    }
}

/// SwiftUI view для отображения уведомления
struct NotificationBannerView: View {
    @ObservedObject var notificationCenter = NotificationCenterService.shared
    
    @State private var showResolution = false

    var body: some View {
        if let notification = notificationCenter.currentNotification {
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading) {
                        Text(title(for: notification.type))
                            .font(.headline)
                        Text(message(for: notification.type))
                            .font(.subheadline)
                        if showResolution, case let .error(_, resolution) = notification.type {
                            Text("💡 Рекомендация: \(resolution)")
                                .font(.footnote)
                                .foregroundColor(.yellow)
                                .padding(.top, 2)
                        }
                    }
                    Spacer()
                    VStack {
                        Button("ОК") {
                            notificationCenter.dismiss()
                        }
                        if case .error = notification.type {
                            Button("Подробнее") {
                                showResolution.toggle()
                            }
                        }
                    }
                }
                .padding()
                .background(backgroundColor(for: notification.type))
                .cornerRadius(12)
                .padding()
                .shadow(radius: 5)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut, value: notification)
        }
    }

    private func title(for type: AppNotificationType) -> String {
        switch type {
        case .success: return "✅ Успех"
        case .warning: return "⚠️ Внимание"
        case .error: return "❌ Ошибка"
        }
    }

    private func message(for type: AppNotificationType) -> String {
        switch type {
        case .success(let msg), .warning(let msg): return msg
        case .error(let msg, _): return msg
        }
    }

    private func backgroundColor(for type: AppNotificationType) -> Color {
        switch type {
        case .success: return Color.green.opacity(0.8)
        case .warning: return Color.orange.opacity(0.8)
        case .error: return Color.red.opacity(0.8)
        }
    }
}
