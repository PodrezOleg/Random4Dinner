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
        db.collection("groups").getDocuments { snapshot, error in
            if let error = error {
                print("Ошибка получения групп: \(error)")
                NotificationCenterService.shared.showWarning("Нет подключения к интернету. Работаете в оффлайн-режиме.")
                completion?()
                return
            }
            guard let docs = snapshot?.documents else {
                print("Нет данных по группам")
                completion?()
                return
            }
            var found: [UserGroup] = []
            for doc in docs {
                if let group = try? doc.data(as: UserGroup.self) {
                    if group.members.contains(where: { $0.id == userId }) {
                        found.append(group)
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
