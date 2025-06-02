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
    @State private var groupToLeave: UserGroup? = nil
    @State private var showLeaveAlert = false
    @State private var errorMessage: String?
    @State private var selection: String? = nil

    private var userId: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Мои группы")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)

                if groupStore.groups.isEmpty {
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
                    List(selection: $selection) {
                        ForEach(groupStore.groups, id: \.id) { group in
                            NavigationLink(
                                destination: GroupDetailView(groupStore: groupStore, group: group),
                                tag: group.id,
                                selection: $selection
                            ) {
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
                                        Image(systemName: "checkmark").foregroundColor(.blue)
                                    }
                                    Button {
                                        groupToLeave = group
                                        showLeaveAlert = true
                                    } label: {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 8)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .alert("Вы действительно хотите выйти из группы?", isPresented: $showLeaveAlert, presenting: groupToLeave) { group in
                        Button("Выйти", role: .destructive) {
                            if let userId = userId {
                                GroupFirestoreService.shared.leaveGroup(groupId: group.id, userId: userId) { result in
                                    switch result {
                                    case .success:
                                        groupStore.fetchGroups(for: userId)
                                        if groupStore.selectedGroup?.id == group.id {
                                            groupStore.selectedGroup = nil
                                        }
                                    case .failure(let err):
                                        errorMessage = "Ошибка: \(err.localizedDescription)"
                                    }
                                }
                            }
                        }
                        Button("Отмена", role: .cancel) { }
                    } message: { group in
                        Text("Это действие нельзя отменить. Вы больше не будете участником группы \"\(group.name)\".")
                    }
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
                    groupStore.fetchGroups(for: userId ?? "")
                    showCreateSheet = false
                }
            }
        }
        .onAppear {
            if groupStore.groups.isEmpty {
                showCreateSheet = true
            }
        }
    }
}
