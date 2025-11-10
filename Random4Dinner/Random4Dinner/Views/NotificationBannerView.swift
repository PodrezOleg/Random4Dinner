//
//  NotificationBannerView.swift
//  Random4Dinner
//
//  Created by Oleg Podрез on 10.05.25.
//

import SwiftUI

struct NotificationBannerView: View {
    @ObservedObject var notificationCenter = NotificationCenterService.shared
    @State private var showResolution = false
    
    private let horizontalPadding: CGFloat = 12
    
    var body: some View {
        GeometryReader { geo in
            if let notification = notificationCenter.currentNotification {
                VStack {
                    Spacer()
                    HStack(alignment: .top, spacing: 12) {
                        // Контент
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title(for: notification.type))
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(0)
                                .minimumScaleFactor(0.8)

                            Text(message(for: notification.type))
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true) // перенос по высоте
                                .multilineTextAlignment(.leading)

                            if showResolution, case let .error(_, resolution) = notification.type {
                                Text("💡 Рекомендация: \(resolution)")
                                    .font(.footnote)
                                    .foregroundColor(.yellow)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                        }

                        Spacer(minLength: 2)

                        // Кнопки
                        VStack(alignment: .trailing, spacing: 8) {
                            Button("ОК") {
                                notificationCenter.dismiss()
                            }
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .buttonStyle(.plain)

                            if case .error = notification.type {
                                Button(showResolution ? "Скрыть" : "Подробнее") {
                                    showResolution.toggle()
                                }
                                .foregroundColor(.white)
                                .font(.subheadline)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .frame(
                        maxWidth: geo.size.width - (horizontalPadding * 2),
                        alignment: .leading
                    )
                    .background(backgroundColor(for: notification.type))
                    .cornerRadius(12)
                    .shadow(radius: 6)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                }
                Spacer()
                
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: notification)
            }
        }
        .ignoresSafeArea(edges: .bottom) // чтобы не конфликтовать с home-indicator
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
        case .success: return Color.green.opacity(0.9)
        case .warning: return Color.orange.opacity(0.9)
        case .error: return Color.red.opacity(0.9)
        case .info: return Color.blue.opacity(0.9)
        }
    }
}
