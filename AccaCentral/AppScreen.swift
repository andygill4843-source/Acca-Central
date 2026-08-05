//
//  AppScreen.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import Foundation
import FirebaseAuth
import SwiftUI

enum AppScreen {
    case splash
    case auth
    case teamSetup
    case main
}

@MainActor
final class AppState: ObservableObject {
    @Published var screen: AppScreen = .splash
    @Published var currentUser: AppUser?

    private let rememberMeKey = "acca.rememberMe"

    var rememberMe: Bool {
        get { UserDefaults.standard.bool(forKey: rememberMeKey) }
        set { UserDefaults.standard.set(newValue, forKey: rememberMeKey) }
    }

    func resolveAuthState() async {
        if !rememberMe {
            try? Auth.auth().signOut()
        }

        guard let firebaseUser = Auth.auth().currentUser else {
            screen = .auth
            return
        }

        do {
            let user = try await AuthService.shared.fetchCurrentUserProfile(uid: firebaseUser.uid)
            currentUser = user
            screen = user.teamIds.isEmpty ? .teamSetup : .main
        } catch {
            screen = .auth
        }
    }

    func didLogIn(as user: AppUser) {
        currentUser = user
        screen = user.teamIds.isEmpty ? .teamSetup : .main
    }

    func didJoinOrCreateTeam(updatedUser: AppUser) {
        currentUser = updatedUser
        screen = .main
    }

    func logOut() {
        try? Auth.auth().signOut()
        currentUser = nil
        rememberMe = false
        screen = .auth
    }
}