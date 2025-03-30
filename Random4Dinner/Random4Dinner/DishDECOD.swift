//
//  DishDECOD.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.03.25.
//

import Foundation
import SwiftData

// Простая структура для декодирования JSON
struct DishDECOD: Codable, Identifiable {
    let id: UUID?
    let name: String
    let about: String
    let imageBase64: String?

    // Создаём ID на основе декодированного объекта, если его нет в JSON
    init(id: UUID = UUID(), name: String, about: String, imageBase64: String?) {
        self.id = id
        self.name = name
        self.about = about
        self.imageBase64 = imageBase64
    }
}
