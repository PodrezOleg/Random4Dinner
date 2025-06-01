//
//  GroupModel.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 24.05.25.
//

import Foundation

struct UserGroup: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?        // Новое поле: описание группы
    var type: String?               // Новое поле: тип группы ("кухня", "семья", ...)
    var ownerId: String
    var members: [GroupMember]
}

struct GroupMember: Identifiable, Codable {
    var id: String        // userId
    var name: String
    var avatarUrl: String?
    var isAdmin: Bool
}

struct GroupInvite: Identifiable, Codable {
    var id: String
    var groupId: String
    var inviterId: String
    var inviteeEmail: String
    var status: String // pending, accepted, declined
    var createdAt: Date
}
