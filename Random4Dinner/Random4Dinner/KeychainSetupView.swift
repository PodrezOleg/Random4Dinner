//
//  KeychainSetupView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 10.05.25.
//

import SwiftUI

struct KeychainSetupView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showSavedMessage = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("WebDAV учётные данные")) {
                    TextField("Логин", text: $username)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    SecureField("Пароль", text: $password)
                }

                Button(action: saveCredentials) {
                    Text("Сохранить в Keychain")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(username.isEmpty || password.isEmpty)

                if showSavedMessage {
                    Text("✅ Учетные данные сохранены!")
                        .foregroundColor(.green)
                }
            }
            .navigationTitle("Настройка Keychain")
        }
    }

    private func saveCredentials() {
        KeychainHelper.shared.save(key: "webdav_username", value: username)
        KeychainHelper.shared.save(key: "webdav_password", value: password)
        showSavedMessage = true

        NotificationCenterService.shared.showSuccess("Учетные данные сохранены в Keychain")
    }
}
