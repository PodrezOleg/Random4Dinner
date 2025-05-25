//
//  GroupStore.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 25.05.25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

class GroupStore: ObservableObject {
    @Published var groups: [UserGroup] = []
    @Published var selectedGroup: UserGroup? = nil

    func fetchGroups(for userId: String, completion: (() -> Void)? = nil) {
        let db = Firestore.firestore()
        db.collection("groups")
            .getDocuments { snapshot, error in
                var found: [UserGroup] = []
                if let docs = snapshot?.documents {
                    for doc in docs {
                        if let group = try? doc.data(as: UserGroup.self) {
                            // Проверяем: состоит ли пользователь в группе
                            if group.members.contains(where: { $0.id == userId }) {
                                found.append(group)
                            }
                        }
                    }
                }
                DispatchQueue.main.async {
                    withAnimation(.easeInOut) {
                        self.groups = found
                        if self.selectedGroup == nil {
                            self.selectedGroup = found.first
                        }
                    }
                    completion?()
                }
            }
    }

    func selectGroup(_ group: UserGroup) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0.5)) {
            self.selectedGroup = group
        }
    }
}
