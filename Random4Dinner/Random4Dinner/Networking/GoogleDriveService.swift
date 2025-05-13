//
//  GoogleDriveService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.05.25.
//

import Foundation
import GoogleSignIn
import GoogleAPIClientForREST_Drive

class GoogleDriveService {
    static let shared = GoogleDriveService()
    private init() {}

    private let driveService = GTLRDriveService()

    func configureAuthorization() {
        driveService.authorizer = GoogleAuthManager.shared.authorizer
    }
    
    func uploadDishesJSON(_ data: Data, fileName: String = "dishes.json", completion: ((Result<String, Error>) -> Void)? = nil) {
        configureAuthorization()

        let file = GTLRDrive_File()
        file.name = fileName
        file.mimeType = "application/json"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
        } catch {
            print("❌ Ошибка записи временного файла: \(error)")
            completion?(.failure(error))
            return
        }

        let uploadParams = GTLRUploadParameters(fileURL: tempURL, mimeType: "application/json")
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParams)

        driveService.executeQuery(query) { (_, result, error) in
            if let error = error {
                print("❌ Ошибка загрузки JSON: \(error.localizedDescription)")
                completion?(.failure(error))
            } else if let file = result as? GTLRDrive_File, let fileID = file.identifier {
                print("✅ JSON файл загружен в Google Drive с ID: \(fileID)")
                completion?(.success(fileID))
            } else {
                print("⚠️ Неизвестный результат при загрузке файла")
            }
        }
    }

    func downloadDishesJSON(fileID: String = "dishes.json", completion: @escaping (Result<Data, Error>) -> Void) {
        configureAuthorization()

        let query = GTLRDriveQuery_FilesList.query()
        query.q = "name='\(fileID)'"
        query.spaces = "drive"

        driveService.executeQuery(query) { (_, result, error) in
            if let error = error {
                print("❌ Ошибка поиска файла в Google Drive: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard
                let list = result as? GTLRDrive_FileList,
                let file = list.files?.first,
                let fileID = file.identifier
            else {
                print("⚠️ Файл не найден")
                completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "Файл не найден"])))
                return
            }

            let downloadQuery = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: fileID)
            self.driveService.executeQuery(downloadQuery) { (_, fileData, error) in
                if let error = error {
                    print("❌ Ошибка скачивания: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let data = (fileData as? GTLRDataObject)?.data {
                    print("📥 JSON файл успешно загружен из Google Drive")
                    completion(.success(data))
                } else {
                    print("⚠️ Данные не получены")
                    completion(.failure(NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Данные не получены"])))
                }
            }
        }
    }

    func uploadImage(_ data: Data, fileName: String, completion: ((Result<String, Error>) -> Void)? = nil) {
        configureAuthorization()

        let file = GTLRDrive_File()
        file.name = fileName
        file.mimeType = "image/jpeg"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
        } catch {
            print("❌ Ошибка записи временного изображения: \(error)")
            completion?(.failure(error))
            return
        }

        let uploadParams = GTLRUploadParameters(fileURL: tempURL, mimeType: "image/jpeg")
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParams)

        driveService.executeQuery(query) { (_, result, error) in
            if let error = error {
                print("❌ Ошибка загрузки изображения: \(error.localizedDescription)")
                completion?(.failure(error))
            } else if let file = result as? GTLRDrive_File, let fileID = file.identifier {
                print("✅ Изображение загружено в Google Drive с ID: \(fileID)")
                completion?(.success(fileID))
            } else {
                print("⚠️ Неизвестный результат при загрузке изображения")
                completion?(.failure(NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Неизвестный результат"])))
            }
        }
    }

    func downloadImage(fileID: String, completion: @escaping (Result<Data, Error>) -> Void) {
        configureAuthorization()

        let query = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: fileID)
        driveService.executeQuery(query) { (_, result, error) in
            if let error = error {
                print("❌ Ошибка скачивания изображения: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let data = (result as? GTLRDataObject)?.data {
                print("📥 Изображение успешно загружено из Google Drive")
                completion(.success(data))
            } else {
                print("⚠️ Данные изображения не получены")
                completion(.failure(NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Данные изображения не получены"])))
            }
        }
    }
}

