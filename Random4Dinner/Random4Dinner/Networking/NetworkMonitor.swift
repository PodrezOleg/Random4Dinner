//
//  NetworkMonitor.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 29.05.25.
//

import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}
