//
//  GroupInviteService.swift .swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 24.05.25.
//

import Foundation
import FirebaseFirestore


final class GroupInviteService {
    static let shared = GroupInviteService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Отправить приглашение
    func sendInvite(groupId: String,
                    inviterId: String,
                    inviteeEmail: String,
                    completion: @escaping (Result<Void, Error>) -> Void) {
        let invite = GroupInvite(
            id: UUID().uuidString,
            groupId: groupId,
            inviterId: inviterId,
            inviteeEmail: inviteeEmail,
            status: "pending",
            createdAt: Date()
        )
        do {
            try db.collection("invites").document(invite.id).setData(from: invite) { error in
                if let error = error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    // Принять приглашение
    func acceptInvite(inviteId: String?,
                      userId: String,
                      displayName: String,
                      avatarUrl: String?,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        let inviteRef = db.collection("invites").document(inviteId ?? "")
        inviteRef.getDocument { snapshot, error in
            if let data = snapshot?.data(), let groupId = data["groupId"] as? String {
                // Добавляем участника в группу
                let member = GroupMember(id: userId,
                                         name: displayName,
                                         avatarUrl: avatarUrl,
                                         isAdmin: false)
                let groupRef = self.db.collection("groups").document(groupId)
                groupRef.updateData([
                    "members": FieldValue.arrayUnion([try! Firestore.Encoder().encode(member)])
                ]) { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    // Обновить статус приглашения
                    inviteRef.updateData(["status": "accepted"]) { err in
                        if let err = err { completion(.failure(err)) }
                        else { completion(.success(())) }
                    }
                }
            } else {
                completion(.failure(error ?? NSError(domain: "Invite not found", code: 0)))
            }
        }
    }

    // Отклонить приглашение
    func declineInvite(inviteId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("invites").document(inviteId).updateData(["status": "declined"]) { error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(())) }
        }
    }
    func getDishesForUser(userId: String, completion: @escaping (Result<[DishDECOD], Error>) -> Void) {
            db.collection("dishes").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    let dishes: [DishDECOD] = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: DishDECOD.self)
                    } ?? []
                    completion(.success(dishes))
                }
            }
        }
    }

