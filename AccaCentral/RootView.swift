//
//  RootView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct RootView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            switch appState.screen {
            case .splash:
                SplashView()
            case .auth:
                AuthView()
            case .teamSetup:
                TeamSetupView()
            case .main:
                MainTabView()
            }
        }
        .environmentObject(appState)
    }
}