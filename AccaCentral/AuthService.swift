//
//  AuthService.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {
    static let shared = AuthService()
    private let db = Firestore.firestore()

    private init() {}

    enum AuthServiceError: LocalizedError {
        case usernameTaken
        case usernameInvalid
        case userNotFound

        var errorDescription: String? {
            switch self {
            case .usernameTaken: return "That username is already taken."
            case .usernameInvalid: return "Usernames must be 3-20 characters, letters/numbers/underscore only."
            case .userNotFound: return "No account found with that username."
            }
        }
    }

    func isValid(username: String) -> Bool {
        let pattern = "^[a-z0-9_]{3,20}$"
        return username.range(of: pattern, options: .regularExpression) != nil
    }

    func signUp(username: String, email: String, password: String, displayName: String) async throws -> AppUser {
        let normalizedUsername = username.lowercased()
        guard isValid(username: normalizedUsername) else { throw AuthServiceError.usernameInvalid }

        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = authResult.user.uid

        let usernameRef = db.collection("usernames").document(normalizedUsername)
        let userRef = db.collection("users").document(uid)

        let user = AppUser(
            id: uid,
            username: normalizedUsername,
            displayName: displayName,
            email: email,
            teamIds: [],
            fcmToken: nil,
            createdAt: Date()
        )

        try await db.runTransaction { transaction, errorPointer in
            let existing = try? transaction.getDocument(usernameRef)
            if existing?.exists == true {
                errorPointer?.pointee = AuthServiceError.usernameTaken as NSError
                return nil
            }
            transaction.setData(["uid": uid], forDocument: usernameRef)
            do {
                try transaction.setData(from: user, forDocument: userRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }

        return user
    }

    func logIn(username: String, password: String) async throws -> AppUser {
        let normalizedUsername = username.lowercased()
        let usernameDoc = try await db.collection("usernames").document(normalizedUsername).getDocument()
        guard let uid = usernameDoc.data()?["uid"] as? String else {
            throw AuthServiceError.userNotFound
        }
        let userDoc = try await db.collection("users").document(uid).getDocument()
        let user = try userDoc.data(as: AppUser.self)

        _ = try await Auth.auth().signIn(withEmail: user.email, password: password)
        return user
    }

    func fetchCurrentUserProfile(uid: String) async throws -> AppUser {
        let doc = try await db.collection("users").document(uid).getDocument()
        return try doc.data(as: AppUser.self)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}