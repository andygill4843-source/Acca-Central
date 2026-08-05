//
//  TeamSetupView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct TeamSetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var mode: Mode = .join

    @State private var teamName = ""
    @State private var season = "2026-27"
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case create, join }

    var body: some View {
        VStack(spacing: 24) {
            Text("Get your team set up")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accaPrimary)
                .padding(.top, 40)

            Picker("Mode", selection: $mode) {
                Text("Join a team").tag(Mode.join)
                Text("Create a team").tag(Mode.create)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)

            VStack(spacing: 14) {
                if mode == .create {
                    field("Team name", text: $teamName)
                    field("Season", text: $season)
                } else {
                    field("Invite code", text: $inviteCode, autocap: true)
                }
            }
            .padding(.horizontal, 24)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accaLoss)
                    .padding(.horizontal, 24)
            }

            Button(action: submit) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(mode == .create ? "Create team" : "Join team")
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.accaGold)
            .foregroundStyle(Color.accaPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .disabled(isLoading)

            Spacer()
        }
        .background(Color.accaBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, autocap: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 13)).foregroundStyle(Color.accaTextSecondary)
            TextField("", text: text)
                .autocapitalization(autocap ? .allCharacters : .words)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
        }
    }

    private func submit() {
        guard let userId = appState.currentUser?.id else { return }
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let team: Team
                if mode == .create {
                    team = try await FirebaseService.shared.createTeam(name: teamName, season: season, managerId: userId)
                } else {
                    team = try await FirebaseService.shared.joinTeam(inviteCode: inviteCode.uppercased(), userId: userId)
                }

                let member = Member(
                    id: nil,
                    userId: userId,
                    displayName: appState.currentUser?.displayName ?? "Player",
                    teamId: team.id ?? "",
                    joinedAt: Date()
                )
                try await FirebaseService.shared.addMember(member)

                var updatedUser = appState.currentUser!
                updatedUser.teamIds.append(team.id ?? "")
                try await FirebaseService.shared.updateUserTeamIds(userId: userId, teamIds: updatedUser.teamIds)

                await MainActor.run {
                    isLoading = false
                    appState.didJoinOrCreateTeam(updatedUser: updatedUser)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
