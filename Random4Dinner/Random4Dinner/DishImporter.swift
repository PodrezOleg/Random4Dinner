//
//  DishImporter.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.03.25.
//

import SwiftData
import SwiftUI

func importDish(from decod: DishDECOD, context: ModelContext) {
    let dish = Dish(name: decod.name, about: decod.about, imageBase64: decod.imageBase64)
    context.insert(dish)
}

