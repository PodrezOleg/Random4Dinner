//
//  GroupDetailView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 2.06.25.

import SwiftUI
import FirebaseAuth

struct GroupDetailView: View {
    @ObservedObject var groupStore: GroupStore
    let group: UserGroup

    @Environment(\.dismiss) private var dismiss
    @State private var showExitAlert = false
    @State private var showInviteSheet = false
    @State private var errorMessage: String? = nil
    @State private var inviteError: String? = nil
    @State private var inviteSuccess: Bool = false

    private var userId: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        VStack(spacing: 20) {
            Text(group.name).font(.title)
            if let desc = group.description {
                Text(desc).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Участники: \(group.members.count)").bold()
                ForEach(group.members, id: \.id) { member in
                    Text(member.name)
                        .foregroundColor(member.id == userId ? .blue : .primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Button("Пригласить в группу") {
                showInviteSheet = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.vertical)

            Spacer()

            Button("Выйти из группы") {
                showExitAlert = true
            }
            .foregroundColor(.red)
            .padding(.bottom)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top)
            }
        }
        .navigationTitle("Группа")
        .padding()
        .sheet(isPresented: $showInviteSheet) {
            InviteUserSheet(
                group: group,
                onInvite: { email in
                    inviteUser(email: email, to: group)
                },
                inviteError: $inviteError,
                inviteSuccess: $inviteSuccess
            )
        }
        .alert("Вы уверены, что хотите выйти из группы?", isPresented: $showExitAlert) {
            Button("Выйти", role: .destructive) {
                leaveGroup()
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    private func leaveGroup() {
        guard let userId = userId else { return }
        GroupFirestoreService.shared.leaveGroup(groupId: group.id, userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    groupStore.fetchGroups(for: userId)
                    dismiss()
                case .failure(let error):
                    errorMessage = "Ошибка выхода: \(error.localizedDescription)"
                }
            }
        }
    }

    private func inviteUser(email: String, to group: UserGroup) {
        if group.members.contains(where: { $0.name == email || $0.id == email }) {
            inviteError = "Этот пользователь уже в группе."
            inviteSuccess = false
            return
        }
        inviteError = nil
        inviteSuccess = false
        GroupInviteService.shared.checkPendingInvite(groupId: group.id, inviteeEmail: email) { alreadySent in
            if alreadySent {
                inviteError = "Приглашение уже отправлено этому пользователю."
                inviteSuccess = false
                return
            }
            GroupInviteService.shared.sendInvite(
                groupId: group.id,
                inviterId: userId ?? "",
                inviteeEmail: email
            ) { result in
                switch result {
                case .success:
                    inviteError = nil
                    inviteSuccess = true
                case .failure(let err):
                    inviteError = "Ошибка: \(err.localizedDescription)"
                    inviteSuccess = false
                }
            }
        }
    }
}
