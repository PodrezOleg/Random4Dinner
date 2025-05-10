//  APIService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.03.25.
//
import Foundation

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError
}

class APIService {
    static let shared = APIService()
    private init() {}

    private let webdavURL = "http://192.168.1.168:8888/remote.php/dav/files/Podrez/Random4DinnerApp/dishes.json"

    private var username: String {
        KeychainHelper.shared.read(key: "webdav_username") ?? ""
    }

    private var password: String {
        KeychainHelper.shared.read(key: "webdav_password") ?? ""
    }

    // 📥 Загрузка
    func fetchDishes() async throws -> [DishDECOD] {
        guard let url = URL(string: webdavURL) else { throw APIError.invalidURL }
        print("🌐 Запрос на: \(webdavURL)")

        var request = URLRequest(url: url)
        request.setBasicAuth(username: username, password: password)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            print("📥 Ответ: \(httpResponse.statusCode)")
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            let container = try JSONDecoder().decode(DishesContainer.self, from: data)
            return container.dishes

        } catch {
            throw APIError.networkError(error)
        }
    }

    // 📤 Сохранение
    func uploadDishes(_ dishes: [DishDECOD]) async throws {
        guard let url = URL(string: webdavURL) else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setBasicAuth(username: username, password: password)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let container = DishesContainer(dishes: dishes)
        let encodedData = try JSONEncoder().encode(container)
        request.httpBody = encodedData

        print("📤 Отправляем на NAS: \(dishes.count) блюд")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("✅ Ответ от NAS: \(httpResponse.statusCode)")
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
}

private extension URLRequest {
    mutating func setBasicAuth(username: String, password: String) {
        let loginString = "\(username):\(password)"
        let loginData = loginString.data(using: .utf8)!.base64EncodedString()
        self.setValue("Basic \(loginData)", forHTTPHeaderField: "Authorization")
    }
}
