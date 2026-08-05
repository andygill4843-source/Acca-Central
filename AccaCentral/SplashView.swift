//
//  SplashView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct SplashView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.accaPrimary.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.accaGold)
                    .frame(width: 108, height: 108)
                    .overlay(
                        Image(systemName: "soccerball")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(Color.accaPrimary)
                    )

                Text("Acca Central")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)

                Text("One Team. One Acca. One Champion.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                Text("Tap to continue")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Task { await appState.resolveAuthState() }
        }
    }
}