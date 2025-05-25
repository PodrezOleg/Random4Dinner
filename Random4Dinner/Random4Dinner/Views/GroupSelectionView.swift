//
//  GroupSelectionView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 25.05.25.
//

import SwiftUI
import FirebaseAuth

struct GroupSelectionView: View {
    @EnvironmentObject var groupStore: GroupStore
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateSheet = false
    @State private var inviteCode = ""
    @State private var joining = false
    @State private var errorMessage: String?
    @State private var showInviteSheet = false
    @State private var inviteError: String?
    @State private var inviteSuccess: Bool = false

    private var userId: String? { Auth.auth().currentUser?.uid }
    private var userName: String { Auth.auth().currentUser?.displayName ?? "User" }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Мои группы")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)

                if groupStore.groups.isEmpty {
                    // Когда групп нет, сразу предлагаем создать
                    VStack(spacing: 16) {
                        Text("У вас пока нет ни одной группы.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Создать первую группу") {
                            showCreateSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 32)
                } else {
                    // Список групп
                    List(selection: Binding(
                        get: { groupStore.selectedGroup?.id },
                        set: { id in
                            if let id, let group = groupStore.groups.first(where: { $0.id == id }) {
                                groupStore.selectGroup(group)
                            }
                            dismiss()
                        }
                    )) {
                        ForEach(groupStore.groups, id: \.id) { group in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(group.name).font(.headline)
                                    if let desc = group.description {
                                        Text(desc).font(.caption).foregroundColor(.secondary)
                                    }
                                    if !group.members.isEmpty {
                                        Text("Участники: " + group.members.map(\.name).joined(separator: ", "))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                if groupStore.selectedGroup?.id == group.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                                if group.ownerId == userId {
                                    Button {
                                        groupStore.selectGroup(group)
                                        showInviteSheet = true
                                    } label: {
                                        Image(systemName: "person.badge.plus")
                                            .foregroundColor(.orange)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 8)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                VStack(spacing: 12) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Создать новую группу", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Divider().padding(.vertical, 4)

                    HStack {
                        TextField("Код приглашения", text: $inviteCode)
                            .textFieldStyle(.roundedBorder)
                        Button("Войти") {
                            joinGroupByInvite()
                        }
                        .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Выбор группы")
            .sheet(isPresented: $showCreateSheet) {
                GroupCreateView { _ in
                    // После создания обновляем список групп
                    groupStore.fetchGroups(for: userId ?? "")
                    showCreateSheet = false
                }
            }
            .sheet(isPresented: $showInviteSheet) {
                if let group = groupStore.selectedGroup {
                    InviteUserSheet(
                        group: group,
                        onInvite: { email in
                            inviteUser(email: email, to: group)
                        },
                        inviteError: $inviteError,
                        inviteSuccess: $inviteSuccess
                    )
                }
            }
        }
        .onAppear {
            // Если совсем нет групп, автопоказываем создание (но только 1 раз, если хочешь)
            if groupStore.groups.isEmpty {
                showCreateSheet = true
            }
        }
    }

    func joinGroupByInvite() {
        joining = true
        errorMessage = nil
        let code = inviteCode.trimmingCharacters(in: .whitespaces)
        GroupInviteService.shared.acceptInvite(
            inviteId: code,
            userId: userId ?? "",
            displayName: userName,
            avatarUrl: nil
        ) { result in
            joining = false
            switch result {
            case .success:
                groupStore.fetchGroups(for: userId ?? "")
                inviteCode = ""
            case .failure(let err):
                errorMessage = "Ошибка: \(err.localizedDescription)"
            }
        }
    }

    func inviteUser(email: String, to group: UserGroup) {
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

// ---- Вью для инвайта ----
struct InviteUserSheet: View {
    let group: UserGroup
    var onInvite: (String) -> Void
    @Binding var inviteError: String?
    @Binding var inviteSuccess: Bool

    @State private var email = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Пригласить пользователя в \"\(group.name)\"")
                    .font(.headline)
                TextField("Email пользователя", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                if let inviteError = inviteError {
                    Text(inviteError).foregroundColor(.red)
                }
                if inviteSuccess {
                    Text("Приглашение отправлено!").foregroundColor(.green)
                }
                Button("Отправить приглашение") {
                    onInvite(email)
                }
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { email = "" }
                }
            }
        }
    }
}
