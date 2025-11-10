//
//  Dish+Snapshot.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 19.10.25.
//


import SwiftData

extension Dish {
    @MainActor
    func snapshotDTO() -> DishDTO {
        .init(from: self) // твой init(from model: Dish)
    }
}
