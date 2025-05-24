//
//  GroupManager.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 24.05.25.
//

import Foundation

final class GroupManager {
    static let shared = GroupManager()
    private init() {}

    // Удалить участника (только админ)
    func removeMember(groupId: String, memberId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Получить группу, убрать участника из members, обновить группу через FirestoreService
        GroupFirestoreService.shared.getGroup(groupId: groupId) { result in
            switch result {
            case .success(var group):
                group.members.removeAll { $0.id == memberId }
                GroupFirestoreService.shared.updateGroup(group, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // Выйти из группы (self-leave)
    func leaveGroup(groupId: String, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Аналогично removeMember, но ещё нужно локально сохранить блюда пользователя
        GroupFirestoreService.shared.getGroup(groupId: groupId) { result in
            switch result {
            case .success(var group):
                group.members.removeAll { $0.id == userId }
                // Локальное сохранение логики (твоё приложение)
                GroupFirestoreService.shared.updateGroup(group) { res in
                    // После успеха — вызвать локальную синхронизацию
                    if case .success = res {
                        // Сохрани блюда на устройстве (реализуй LocalStorageHelper)
                        LocalStorageHelper.saveDishesForUser(userId: userId)
                    }
                    completion(res)
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // Передать права администратора
    func transferAdmin(groupId: String, newAdminId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        GroupFirestoreService.shared.getGroup(groupId: groupId) { result in
            switch result {
            case .success(var group):
                if let idx = group.members.firstIndex(where: { $0.id == newAdminId }) {
                    for i in 0..<group.members.count {
                        group.members[i].isAdmin = (i == idx)
                    }
                    group.ownerId = newAdminId
                    GroupFirestoreService.shared.updateGroup(group, completion: completion)
                } else {
                    completion(.failure(NSError(domain: "User not in group", code: 0)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
