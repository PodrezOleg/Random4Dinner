//
//  Dish.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftData
import SwiftUI

@Model
class Dish  {
    var name: String
    var about: String
    var image: Data?
    
    init(name: String, about: String, image: Data? = nil) {
        self.name = name
        self.about = about
        self.image = image
    }
}
