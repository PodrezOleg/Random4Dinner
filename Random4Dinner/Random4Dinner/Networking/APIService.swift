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
        guard let url = URL(string: webdavURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        let loginString = "\(username):\(password)"
        let loginData = loginString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(loginData)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("📥 Статус ответа при загрузке: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        do {
            let container = try JSONDecoder().decode(DishesContainer.self, from: data)
            return container.dishes
        } catch {
            throw APIError.decodingError
        }
    }

    // 📤 Сохранение
    func uploadDishes(_ dishes: [DishDECOD]) async throws {
        guard let url = URL(string: webdavURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        let loginString = "\(username):\(password)"
        let loginData = loginString.data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(loginData)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let container = DishesContainer(dishes: dishes)
        print("📤 Отправляем на NAS: \(dishes.count) блюд")
        let encodedData = try JSONEncoder().encode(container)
        request.httpBody = encodedData

        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print("✅ Ответ от NAS: \(httpResponse.statusCode)")
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
        } else {
            throw APIError.invalidResponse
        }
    }
}
