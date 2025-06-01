//
//  GroupFirestoreService.swift
//  Random4Dinner
//
//  Created by Oleg Podrez on 24.05.25.
//

import Foundation
import FirebaseFirestore
    
//MARK: firebase policy nedd to be changed 
final class GroupFirestoreService {
    static let shared = GroupFirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Group CRUD

    func createGroup(_ group: UserGroup, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection("groups").document(group.id).setData(from: group, completion: { error in
                if let error = error { completion(.failure(error)) }
                else { completion(.success(())) }
            })
        } catch {
            completion(.failure(error))
        }
    }

    func updateGroup(_ group: UserGroup, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection("groups").document(group.id).setData(from: group, merge: true, completion: { error in
                if let error = error { completion(.failure(error)) }
                else { completion(.success(())) }
            })
        } catch {
            completion(.failure(error))
        }
    }

    func getGroup(groupId: String, completion: @escaping (Result<UserGroup, Error>) -> Void) {
        db.collection("groups").document(groupId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = snapshot?.data(),
                  let group = try? Firestore.Decoder().decode(UserGroup.self, from: data) else {
                completion(.failure(NSError(domain: "Group not found", code: 0)))
                return
            }
            completion(.success(group))
        }
    }
    func getDishesForUser(userId: String, completion: @escaping (Result<[DishDECOD], Error>) -> Void) {
         db.collection("dishes").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
             if let error = error {
                 completion(.failure(error))
             } else {
                 let dishes: [DishDECOD] = snapshot?.documents.compactMap { doc in
                     try? doc.data(as: DishDECOD.self)
                 } ?? []
                 completion(.success(dishes))
             }
         }
     }

     // Пример метода для сохранения блюда
     func addDish(_ dish: DishDECOD, userId: String, completion: @escaping (Error?) -> Void) {
         do {
             var dishToSave = dish
             // добавь userId в dishToSave, если структура позволяет
             let _ = try db.collection("dishes").addDocument(from: dishToSave)
             completion(nil)
         } catch {
             completion(error)
         }
     }
 }

