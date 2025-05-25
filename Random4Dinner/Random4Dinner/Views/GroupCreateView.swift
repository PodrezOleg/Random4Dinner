//
//  GroupCreateView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 25.05.25.
//

import SwiftUI
import FirebaseAuth

struct GroupCreateView: View {
    var onComplete: (UserGroup) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var groupName: String = ""
    @State private var groupDesc: String = ""
    @State private var error: String?

    private var userId: String? { Auth.auth().currentUser?.uid }
    private var userName: String { Auth.auth().currentUser?.displayName ?? "User" }
    private var userEmail: String { Auth.auth().currentUser?.email ?? "" }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Название группы")) {
                    TextField("Например: Наша семья", text: $groupName)
                }
                Section(header: Text("Описание (необязательно)")) {
                    TextField("Например: общий список ужинов", text: $groupDesc)
                }
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.top)
                }
            }
            .navigationTitle("Создать группу")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        createGroup()
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createGroup() {
        guard let userId = userId else {
            error = "Нет авторизации"
            return
        }
        // Создаём структуру UserGroup с текущим пользователем — владельцем и единственным участником (isAdmin = true)
        let group = UserGroup(
            id: UUID().uuidString,
            name: groupName,
            description: groupDesc,
            type: "family",
            ownerId: userId,
            members: [
                GroupMember(
                    id: userId,
                    name: userName,
                    avatarUrl: nil,
                    isAdmin: true
                )
            ]
        )

        GroupFirestoreService.shared.createGroup(group) { result in
            switch result {
            case .success:
                onComplete(group)
                dismiss()
            case .failure(let err):
                error = "Ошибка создания: \(err.localizedDescription)"
            }
        }
    }
}
