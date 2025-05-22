//
//  GoogleDriveService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 13.05.25.
//

import Foundation
import GoogleSignIn
import GoogleAPIClientForREST_Drive
import SwiftData

class GoogleDriveService {
    static let shared = GoogleDriveService()
    private init() {}

    private let driveService = GTLRDriveService()

    enum DriveServiceError: Error {
        case notAuthorized
    }

    func configureAuthorization() throws {
        guard let auth = GoogleAuthManager.shared.authorizer else {
            throw DriveServiceError.notAuthorized
        }
        driveService.authorizer = auth
    }
    
    @MainActor
    func importFromGoogleDrive(context: ModelContext) async {
      guard GoogleAuthManager.shared.isSignedIn else {
        print("❌ Попытка импорта без входа в Google")
        NotificationCenterService.shared.showError(
          "Нужно войти в Google", resolution: "Пожалуйста, авторизуйтесь"
        )
        return
      }
    }

    func uploadDishesJSON(_ data: Data, fileName: String = "dishes.json", completion: ((Result<String, Error>) -> Void)? = nil) {
        do {
            try configureAuthorization()
        } catch {
            completion?(.failure(error))
            return
        }
        // Шаг 1. Найти файл с таким именем
        let searchQuery = GTLRDriveQuery_FilesList.query()
        searchQuery.q = "name='\(fileName)' and trashed=false"
        searchQuery.spaces = "drive"
        driveService.executeQuery(searchQuery) { [weak self] (_, result, error) in
            guard let self = self else { return }
            if let error = error {
                completion?(.failure(error))
                return
            }
            let fileList = result as? GTLRDrive_FileList
            let existingFile = fileList?.files?.first
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try data.write(to: tempURL)
            } catch {
                completion?(.failure(error))
                return
            }
            let uploadParams = GTLRUploadParameters(fileURL: tempURL, mimeType: "application/json")
            if let file = existingFile, let fileID = file.identifier {
                // Шаг 2. Файл найден, делаем update
                let updateFile = GTLRDrive_File()
                updateFile.name = fileName
                updateFile.mimeType = "application/json"
                let updateQuery = GTLRDriveQuery_FilesUpdate.query(withObject: updateFile, fileId: fileID, uploadParameters: uploadParams)
                self.driveService.executeQuery(updateQuery) { (_, updateResult, updateError) in
                    if let updateError = updateError {
                        completion?(.failure(updateError))
                    } else {
                        completion?(.success(fileID))
                    }
                }
            } else {
                // Шаг 3. Файла нет — создаём новый
                let newFile = GTLRDrive_File()
                newFile.name = fileName
                newFile.mimeType = "application/json"
                let createQuery = GTLRDriveQuery_FilesCreate.query(withObject: newFile, uploadParameters: uploadParams)
                self.driveService.executeQuery(createQuery) { (_, createResult, createError) in
                    if let createError = createError {
                        completion?(.failure(createError))
                    } else if let file = createResult as? GTLRDrive_File, let fileID = file.identifier {
                        completion?(.success(fileID))
                    } else {
                        completion?(.failure(NSError(domain: "", code: 500, userInfo: [NSLocalizedDescriptionKey: "Неизвестный результат"])))
                    }
                }
            }
        }
    }

    func downloadDishesJSON(
          fileID: String = "dishes.json",
          completion: @escaping (Result<Data, Error>) -> Void
      ) {
        do {
            try configureAuthorization()
        } catch {
            completion(.failure(error))
            return
        }

        // Query for the file by name
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
                completion(.failure(NSError(
                    domain: "",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Файл не найден"]
                )))
                return
            }

            // Download the found file
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
                    completion(.failure(NSError(
                        domain: "",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Данные не получены"]
                    )))
                }
            }
        }
    }

    func uploadImage(_ data: Data, fileName: String, completion: ((Result<String, Error>) -> Void)? = nil) {
        do {
            try configureAuthorization()
        } catch {
            completion?(.failure(error))
            return
        }

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
        do {
            try configureAuthorization()
        } catch {
            completion(.failure(error))
            return
        }

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
