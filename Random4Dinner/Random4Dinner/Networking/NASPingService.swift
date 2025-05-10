//
//  NASPingService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 10.05.25.
//

import Foundation

class NASPingService {
    static let shared = NASPingService()
    
    private let testURL = URL(string: "http://192.168.1.168:8888/remote.php/dav/files/Podrez/Random4DinnerApp/dishes.json")!

    func pingNAS() async {
        var request = URLRequest(url: testURL)
        request.httpMethod = "HEAD"

        let username = KeychainHelper.shared.read(key: "webdav_username") ?? ""
        let password = KeychainHelper.shared.read(key: "webdav_password") ?? ""
        let loginString = "\(username):\(password)"
        if let loginData = loginString.data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(loginData)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    print("✅ NAS доступен (status \(httpResponse.statusCode))")
                } else {
                    print("🚫 NAS не отвечает (status: \(httpResponse.statusCode))")
                }
            }
        } catch {
            print("🚫 Ошибка пинга NAS: \(error.localizedDescription)")
        }
    }

    func isReachable() async -> Bool {
        var request = URLRequest(url: testURL)
        request.httpMethod = "HEAD"

        let username = KeychainHelper.shared.read(key: "webdav_username") ?? ""
        let password = KeychainHelper.shared.read(key: "webdav_password") ?? ""
        let loginString = "\(username):\(password)"
        if let loginData = loginString.data(using: .utf8)?.base64EncodedString() {
            request.setValue("Basic \(loginData)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...299).contains(httpResponse.statusCode)
            }
        } catch {
            return false
        }

        return false
    }
}
