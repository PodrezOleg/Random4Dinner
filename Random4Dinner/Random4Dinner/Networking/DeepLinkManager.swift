// DeepLinkManager.swift
// Random4Dinner

import Foundation
import SwiftUI

enum DeepLink {
    case invite(groupId: String, inviteId: String?)
    case dish(id: UUID)
    case unknown
}

struct DeepLinkManager {
    static func parse(url: URL) -> DeepLink {
        // Поддерживаем и custom-scheme, и https (на будущее)
        // Примеры:
        // random4dinner://invite?groupId=G123&inviteId=I456
        // random4dinner://dish?id=UUID
        // https://yourdomain.app/invite?groupId=...&inviteId=...

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host = url.host?.lowercased()
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let q = comps?.queryItems ?? []
        func value(_ name: String) -> String? { q.first(where: { $0.name == name })?.value }

        if host == "invite" || path == "invite" {
            if let groupId = value("groupId") {
                return .invite(groupId: groupId, inviteId: value("inviteId"))
            }
        } else if host == "dish" || path == "dish" {
            if let idStr = value("id"), let id = UUID(uuidString: idStr) {
                return .dish(id: id)
            }
        }
        return .unknown
    }

    // Centralized handling used by MainContentView (and can be reused elsewhere)
    @MainActor static func handle(
        _ deepLink: DeepLink,
        groupStore: GroupStore,
        openDish: (UUID) -> Void,
        presentAlert: (String) -> Void
    ) {
        switch deepLink {
        case .invite(let groupId, _):
            // Сохраняем выбранную группу локально, чтобы пользователь увидел её в "Группах"
            groupStore.selectedGroup = UserGroup(id: groupId, name: "", ownerId: "", members: [])
            presentAlert("Приглашение получено. Откройте раздел “Мои группы”, чтобы присоединиться.")
        case .dish(let id):
            openDish(id)
        case .unknown:
            presentAlert("Не удалось обработать ссылку.")
        }
    }
}
