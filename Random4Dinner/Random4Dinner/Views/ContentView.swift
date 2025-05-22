//  ContentView.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.03.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var dishes: [Dish]

    @State private var selectedDish: Dish?
    @State private var isAddingDish = false
    @State private var isShowingList = false
    @State private var errorMessage: String? = nil
   

    var body: some View {
        NavigationStack {
            MainContentView(
                selectedDish: $selectedDish,
                isAddingDish: $isAddingDish,
                isShowingList: $isShowingList,
                errorMessage: $errorMessage
            )
        }
        .modifier(AppLifecycleModifier(errorMessage: $errorMessage)) 
    }
}
    
extension Dish {
    func update(from decoded: DishDECOD) {
        self.name = decoded.name ?? ""
        self.about = decoded.about ?? ""
        self.imageBase64 = decoded.imageBase64
    }
}
