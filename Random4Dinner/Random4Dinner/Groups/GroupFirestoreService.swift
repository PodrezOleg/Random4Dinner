//
//  GroupFirestoreService.swift
//  Random4Dinner
//
//  Created by Oleg Podрез on 24.05.25.
//

import Foundation
import FirebaseFirestore
    
//MARK: firebase policy nedd to be changed 
final class GroupFirestoreService {
    static let shared = GroupFirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Group CRUD

    func createGroup(_ group: UserGroup, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection("groups").document(group.id).setData(from: group, completion: { error in
                if let error = error { completion(.failure(error)) }
                else { completion(.success(())) }
            })
        } catch {
            completion(.failure(error))
        }
    }

    func updateGroup(_ group: UserGroup, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection("groups").document(group.id).setData(from: group, merge: true, completion: { error in
                if let error = error { completion(.failure(error)) }
                else { completion(.success(())) }
            })
        } catch {
            completion(.failure(error))
        }
    }

    func getGroup(groupId: String, completion: @escaping (Result<UserGroup, Error>) -> Void) {
        db.collection("groups").document(groupId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = snapshot?.data(),
                  let group = try? Firestore.Decoder().decode(UserGroup.self, from: data) else {
                completion(.failure(NSError(domain: "Group not found", code: 0)))
                return
            }
            completion(.success(group))
        }
    }

    // MARK: - Dishes helpers (используются при удалении группы)
    enum GroupDeleteDishesMode {
        case deleteAll
        case ungroupToPersonal // установить groupId = nil
    }

    // Удаление/разгруппировка блюд, привязанных к группе
    private func handleGroupDishes(for groupId: String, mode: GroupDeleteDishesMode, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("dishes")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { snapshot, error in
                if let error = error { completion(.failure(error)); return }
                let batch = self.db.batch()
                snapshot?.documents.forEach { doc in
                    switch mode {
                    case .deleteAll:
                        batch.deleteDocument(doc.reference)
                    case .ungroupToPersonal:
                        batch.updateData(["groupId": FieldValue.delete()], forDocument: doc.reference)
                    }
                }
                batch.commit { err in
                    if let err = err { completion(.failure(err)) }
                    else { completion(.success(())) }
                }
            }
    }

    // Удаление всех инвайтов группы
    private func deleteAllInvites(for groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("invites")
            .whereField("groupId", isEqualTo: groupId)
            .getDocuments { snapshot, error in
                if let error = error { completion(.failure(error)); return }
                let batch = self.db.batch()
                snapshot?.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }
                batch.commit { err in
                    if let err = err { completion(.failure(err)) }
                    else { completion(.success(())) }
                }
            }
    }

    // Удаление документа группы
    private func deleteGroupDocument(groupId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("groups").document(groupId).delete { error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(())) }
        }
    }

    // Главный метод удаления группы (только владелец)
    func deleteGroup(groupId: String,
                     ownerId: String,
                     dishesMode: GroupDeleteDishesMode,
                     completion: @escaping (Result<Void, Error>) -> Void) {

        // 1) Проверяем, что удаляет владелец
        getGroup(groupId: groupId) { result in
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success(let group):
                guard group.ownerId == ownerId else {
                    completion(.failure(NSError(domain: "Only owner can delete group", code: 403)))
                    return
                }
                // 2) Сначала чистим инвайты
                self.deleteAllInvites(for: groupId) { invitesResult in
                    switch invitesResult {
                    case .failure(let err): completion(.failure(err))
                    case .success:
                        // 3) Потом блюда (удалить или разгруппировать)
                        self.handleGroupDishes(for: groupId, mode: dishesMode) { dishesResult in
                            switch dishesResult {
                            case .failure(let err): completion(.failure(err))
                            case .success:
                                // 4) Удаляем сам документ группы
                                self.deleteGroupDocument(groupId: groupId, completion: completion)
                            }
                        }
                    }
                }
            }
        }
    }
}
