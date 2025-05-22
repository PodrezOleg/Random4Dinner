//
//  NotificationBannerView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 10.05.25.
//

import SwiftUI

struct NotificationBannerView: View {
    @ObservedObject var notificationCenter = NotificationCenterService.shared
    @State private var showResolution = false

    var body: some View {
        if let notification = notificationCenter.currentNotification {
            VStack {
                Spacer()
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title(for: notification.type))
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(message(for: notification.type))
                            .font(.subheadline)
                            .foregroundColor(.white)

                        if showResolution, case let .error(_, resolution) = notification.type {
                            Text("💡 Рекомендация: \(resolution)")
                                .font(.footnote)
                                .foregroundColor(.yellow)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Button("ОК") {
                            notificationCenter.dismiss()
                        }
                        .foregroundColor(.white)

                        if case .error = notification.type {
                            Button("Подробнее") {
                                showResolution.toggle()
                            }
                            .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .background(backgroundColor(for: notification.type))
                .cornerRadius(12)
                .padding()
                .shadow(radius: 6)
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
        case .info: return "ℹ️ Инфо"
        }
    }

    private func message(for type: AppNotificationType) -> String {
        switch type {
        case .success(let msg), .warning(let msg), .info(let msg):
            return msg
        case .error(let msg, _):
            return msg
        }
    }

    private func backgroundColor(for type: AppNotificationType) -> Color {
        switch type {
        case .success: return Color.green.opacity(0.8)
        case .warning: return Color.orange.opacity(0.8)
        case .error: return Color.red.opacity(0.8)
        case .info: return Color.blue.opacity(0.8)
        }
    }
}
