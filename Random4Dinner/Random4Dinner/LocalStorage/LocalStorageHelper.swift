//
//  LocalStorageHelper.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 11.05.25.
//

import Foundation

enum LocalStorageHelper {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var dishesJSONURL: URL {
        documentsDirectory.appendingPathComponent("dishes.json")
    }

    static var imagesDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("images")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func saveImage(data: Data, for dishID: UUID) throws -> String {
        let imageURL = imagesDirectory.appendingPathComponent("\(dishID).jpg")
        try data.write(to: imageURL)
        return "images/\(dishID).jpg"
    }

    static func loadImage(for dishID: UUID) -> Data? {
        let imageURL = imagesDirectory.appendingPathComponent("\(dishID).jpg")
        return try? Data(contentsOf: imageURL)
    }

    static func deleteImage(for dishID: UUID) {
        let imageURL = imagesDirectory.appendingPathComponent("\(dishID).jpg")
        try? FileManager.default.removeItem(at: imageURL)
    }

    static func jsonExists() -> Bool {
        FileManager.default.fileExists(atPath: dishesJSONURL.path)
    }

    static func readJSONData() -> Data? {
        try? Data(contentsOf: dishesJSONURL)
    }

    static func writeJSONData(_ data: Data) throws {
        try data.write(to: dishesJSONURL, options: .atomic)
    }

    static func deleteJSON() throws {
        try FileManager.default.removeItem(at: dishesJSONURL)
    }
}

