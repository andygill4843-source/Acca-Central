//
//  LeagueTableView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct LeagueTableView: View {
    @EnvironmentObject var appState: AppState
    @State private var entries: [LeagueTableEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(Color.accaLoss)
                } else {
                    List {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(index == 0 ? Color.accaGold : Color.accaTextSecondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.displayName)
                                        .font(.system(size: 15, weight: .medium))
                                    Text("\(entry.legsWon)/\(entry.legsPlayed) legs won")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.accaTextSecondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(entry.totalBasePoints) pts")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.accaPrimary)
                                    Text(String(format: "%.1f weighted", entry.totalWeightedPoints))
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.accaTextSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("League table")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        guard let teamId = appState.currentUser?.teamIds.first else {
            errorMessage = "No team found."
            isLoading = false
            return
        }
        do {
            async let members = FirebaseService.shared.fetchMembers(teamId: teamId)
            async let legs = FirebaseService.shared.fetchLegs(teamId: teamId)
            let (m, l) = try await (members, legs)
            entries = ScoringEngine.buildLeagueTable(members: m, legs: l)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}