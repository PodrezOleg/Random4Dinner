//
//  GroupInviteService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 25.05.25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class GroupInviteService {
    static let shared = GroupInviteService()
    private let db = Firestore.firestore()

    private init() {}

    // --- Проверка, отправлено ли уже приглашение этому email в эту группу ---
    func checkPendingInvite(groupId: String, inviteeEmail: String, completion: @escaping (Bool) -> Void) {
        db.collection("invites")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("inviteeEmail", isEqualTo: inviteeEmail)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, error in
                if let docs = snapshot?.documents, !docs.isEmpty {
                    completion(true) // уже есть такое приглашение
                } else {
                    completion(false)
                }
            }
    }

    // --- Отправка приглашения ---
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
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // --- Принять приглашение ---
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
                        if let err = err {
                            completion(.failure(err))
                        } else {
                            completion(.success(()))
                        }
                    }
                }
            } else {
                completion(.failure(error ?? NSError(domain: "Invite not found", code: 0)))
            }
        }
    }

    // --- Отклонить приглашение ---
    func declineInvite(inviteId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("invites").document(inviteId).updateData(["status": "declined"]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
