//
//  InviteUserSheet.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 2.06.25.
//

import SwiftUI


struct InviteUserSheet: View {
    let group: UserGroup
    var onInvite: (String) -> Void
    @Binding var inviteError: String?
    @Binding var inviteSuccess: Bool

    @State private var email = ""
    @Environment(\.dismiss) private var dismiss

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
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}
