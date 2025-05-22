//
//  ViewControllerResolver.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 22.05.25.
//

import SwiftUI

/// SwiftUI helper for getting a native UIViewController.
/// Use for presenting UIKit-based UI (e.g. Google Sign-In) from SwiftUI.
public struct ViewControllerResolver: UIViewControllerRepresentable {
    public var onResolve: (UIViewController) -> Void

    public init(onResolve: @escaping (UIViewController) -> Void) {
        self.onResolve = onResolve
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DispatchQueue.main.async {
            self.onResolve(controller)
        }
        return controller
    }
    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
