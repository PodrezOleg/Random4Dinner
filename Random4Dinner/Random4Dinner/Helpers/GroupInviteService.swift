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

    private func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // --- Проверка, отправлено ли уже приглашение этому email в эту группу ---
    func checkPendingInvite(groupId: String, inviteeEmail: String, completion: @escaping (Bool) -> Void) {
        let normalized = normalizeEmail(inviteeEmail)
        db.collection("invites")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("inviteeEmailLower", isEqualTo: normalized)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, _ in
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
        let normalized = normalizeEmail(inviteeEmail)
        let invite = GroupInvite(
            id: UUID().uuidString,
            groupId: groupId,
            inviterId: inviterId,
            inviteeEmail: inviteeEmail,
            inviteeEmailLower: normalized,
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

    // --- Повторная отправка приглашения (обновление существующего pending) ---
    func resendInviteIfPending(groupId: String,
                               inviteeEmail: String,
                               completion: @escaping (Result<Void, Error>) -> Void) {
        let normalized = normalizeEmail(inviteeEmail)
        db.collection("invites")
            .whereField("groupId", isEqualTo: groupId)
            .whereField("inviteeEmailLower", isEqualTo: normalized)
            .whereField("status", isEqualTo: "pending")
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let doc = snapshot?.documents.first else {
                    completion(.failure(NSError(domain: "NoPendingInvite", code: 0)))
                    return
                }
                // Можно хранить счетчик/время последней отправки
                doc.reference.updateData([
                    "createdAt": Timestamp(date: Date())
                ]) { err in
                    if let err = err {
                        completion(.failure(err))
                    } else {
                        completion(.success(()))
                    }
                }
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
                let member = GroupMember(id: userId,
                                         name: displayName,
                                         avatarUrl: avatarUrl,
                                         isAdmin: false)
                let groupRef = self.db.collection("groups").document(groupId)
                do {
                    let memberData = try Firestore.Encoder().encode(member)
                    groupRef.updateData([
                        "members": FieldValue.arrayUnion([memberData])
                    ]) { error in
                        if let error = error {
                            completion(.failure(error))
                            return
                        }
                        inviteRef.updateData(["status": "accepted"]) { err in
                            if let err = err {
                                completion(.failure(err))
                            } else {
                                completion(.success(()))
                            }
                        }
                    }
                } catch {
                    completion(.failure(error))
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
