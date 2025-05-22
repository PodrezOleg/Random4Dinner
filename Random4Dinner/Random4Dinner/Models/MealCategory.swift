//
//  MealCategory.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 10.05.25.
//

import Foundation

enum MealCategory: String, CaseIterable, Codable, Identifiable {
    case breakfast = "Завтрак"
    case lunch = "Обед"
    case dinner = "Ужин"
    case snack = "Перекус"

    var id: String { self.rawValue }
}
