//
//  GrowingTextEditor.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 30.05.25.
//

import SwiftUI

struct GrowingTextEditor: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(minHeight: 100, maxHeight: .infinity, alignment: .top)
    }
}

// Для удобства — расширение:
extension View {
    func growingTextEditor() -> some View {
        self.modifier(GrowingTextEditor())
    }
}
