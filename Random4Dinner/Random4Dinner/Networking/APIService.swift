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
    static let shared = APIService() //Singelton
    
    private init() {}
    
    func fetchDishes() async throws -> [DishDECOD] {
        guard let url = URL(string: "https://gist.githubusercontent.com/PodrezOleg/b97c4bd985c7e5f4524d86363bd01a77/raw/8de7efabe196a2b51fc15ba232673dfce13ff7f2/dishes.json") else {
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw APIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let container = try decoder.decode(DishesContainer.self, from: data) // С учётом ключа "dishes"
            return container.dishes
        } catch {
            throw APIError.networkError(error)
        }
    }
}
// Контейнер для декодирования JSON
struct DishesContainer: Codable {
    let dishes: [DishDECOD]
}
