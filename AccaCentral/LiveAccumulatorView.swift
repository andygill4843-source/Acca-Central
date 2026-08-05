//
//  LiveAccumulatorView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct LiveAccumulatorView: View {
    @EnvironmentObject var appState: AppState
    @State private var legs: [AccumulatorLeg] = []
    @State private var fixtures: [String: FootballAPIService.Fixture] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?
    @State private var isManager = false
    @State private var showingGameWeekSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(Color.accaLoss)
                } else if legs.isEmpty {
                    Text("No legs submitted for this gameweek yet.")
                        .foregroundStyle(Color.accaTextSecondary)
                } else {
                    List(legs) { leg in
                        legRow(for: leg)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Live")
            .toolbar {
                if isManager {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingGameWeekSetup = true
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingGameWeekSetup, onDismiss: {
                Task { await loadCurrentGameWeekLegs() }
            }) {
                GameWeekSetupView()
                    .environmentObject(appState)
            }
            .task {
                await checkIfManager()
                await loadCurrentGameWeekLegs()
                startPolling()
            }
            .onDisappear {
                pollTask?.cancel()
            }
        }
    }

    @ViewBuilder
    private func legRow(for leg: AccumulatorLeg) -> some View {
        let fixture = fixtures[leg.fixtureId]
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(leg.fixtureDescription)
                    .font(.system(size: 14, weight: .medium))
                Text(leg.selectionDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accaTextSecondary)
            }

            Spacer()

            if let fixture {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(scoreText(for: fixture))
                        .font(.system(size: 15, weight: .semibold))
                    Text(statusLabel(for: fixture))
                        .font(.system(size: 11))
                        .foregroundStyle(statusColor(for: fixture))
                }
            } else {
                Text("—")
                    .foregroundStyle(Color.accaTextSecondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func scoreText(for fixture: FootballAPIService.Fixture) -> String {
        guard let home = fixture.score.fullTime.home, let away = fixture.score.fullTime.away else {
            return "vs"
        }
        return "\(home) - \(away)"
    }
    
    private func checkIfManager() async {
        guard let teamId = appState.currentUser?.teamIds.first,
              let userId = appState.currentUser?.id else { return }
        if let team = try? await FirebaseService.shared.fetchTeam(teamId: teamId) {
            isManager = team.managerId == userId
        }
    }

    private func statusLabel(for fixture: FootballAPIService.Fixture) -> String {
        switch fixture.status {
        case "IN_PLAY", "PAUSED": return "Live"
        case "FINISHED": return "Full time"
        case "SCHEDULED": return "Kickoff soon"
        default: return fixture.status.capitalized
        }
    }

    private func statusColor(for fixture: FootballAPIService.Fixture) -> Color {
        switch fixture.status {
        case "IN_PLAY", "PAUSED": return Color.accaLive
        case "FINISHED": return Color.accaTextSecondary
        default: return Color.accaPending
        }
    }

    private func loadCurrentGameWeekLegs() async {
        guard let teamId = appState.currentUser?.teamIds.first else {
            errorMessage = "No team found."
            isLoading = false
            return
        }
        do {
            let gameWeeks = try await FirebaseService.shared.fetchGameWeeks(teamId: teamId)
            let now = Date()
            let current = gameWeeks.first { $0.startDate <= now && now <= $0.endDate }
                ?? gameWeeks.last { $0.startDate <= now }
                ?? gameWeeks.first

            guard let currentGameWeek = current, let gameWeekId = currentGameWeek.id else {
                errorMessage = "No active gameweek."
                isLoading = false
                return
            }

            legs = try await FirebaseService.shared.fetchLegs(teamId: teamId, gameWeekId: gameWeekId)
            isLoading = false
            await refreshFixtures()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func refreshFixtures() async {
        for leg in legs {
            guard let fixtureId = Int(leg.fixtureId) else { continue }
            if let fetched = try? await FootballAPIService.shared.fetchFixture(id: fixtureId) {
                fixtures[leg.fixtureId] = fetched
            }
        }
    }

    private func startPolling() {
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                if Task.isCancelled { break }
                await refreshFixtures()
            }
        }
    }
}
