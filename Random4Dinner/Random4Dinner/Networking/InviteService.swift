//
//  InviteService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 9.06.25.
//

import FirebaseFirestore

final class InviteService {
    static let shared = InviteService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Отправка инвайта (email или просто генерация ссылки)
    func sendInvite(groupId: String, inviterId: String, inviteeEmail: String?, completion: @escaping (Result<String, Error>) -> Void) {
        var data: [String: Any] = [
            "groupId": groupId,
            "inviterId": inviterId,
            "status": "pending",
            "createdAt": Timestamp()
        ]
        if let inviteeEmail = inviteeEmail {
            data["inviteeEmail"] = inviteeEmail
        }
        let ref = db.collection("invites").document()
        ref.setData(data) { error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(ref.documentID)) }
        }
    }
    
    // Принять инвайт
    func acceptInvite(inviteId: String, userId: String, displayName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let inviteRef = db.collection("invites").document(inviteId)
        inviteRef.getDocument { snap, err in
            guard let data = snap?.data(), let groupId = data["groupId"] as? String else {
                completion(.failure(NSError(domain: "No invite", code: 0)))
                return
            }
            // Добавить пользователя в группу
            let groupRef = self.db.collection("groups").document(groupId)
            groupRef.updateData([
                "members": FieldValue.arrayUnion([
                    ["id": userId, "name": displayName, "isAdmin": false]
                ])
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    inviteRef.updateData(["status": "accepted"])
                    completion(.success(()))
                }
            }
        }
    }
    
    // Отклонить инвайт
    func declineInvite(inviteId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("invites").document(inviteId).updateData([
            "status": "declined"
        ]) { error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(())) }
        }
    }
}
