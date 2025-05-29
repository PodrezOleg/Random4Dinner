//
//  DishImporter.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.03.25.
//

import SwiftData
import SwiftUI

func importDish(from decod: DishDECOD, context: ModelContext) {
    Task { @MainActor in
        let dish = Dish(
            name: decod.name ?? "",
            about: decod.about ?? "",
            imageBase64: decod.imageBase64 ?? "",
            category: decod.category,
            userId: decod.userId,
            groupId: decod.groupId
        )
        context.insert(dish)
    }
}


