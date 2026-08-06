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
    @State private var fixtures: [String: FootballAPIService.Fixture] = [:] // keyed by leg.id
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?

    @State private var isManager = false
    @State private var showingGameWeekSetup = false
    @State private var showingSubmitLeg = false
    @State private var currentGameWeekId: String?
    @State private var currentMemberId: String?

    private var hasSubmittedLeg: Bool {
        guard let currentMemberId else { return false }
        return legs.contains { $0.memberId == currentMemberId }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !isLoading && errorMessage == nil && currentGameWeekId != nil && !hasSubmittedLeg {
                    Button {
                        showingSubmitLeg = true
                    } label: {
                        Text("Pick your leg for this gameweek")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(12)
                    }
                    .background(Color.accaGold)
                    .foregroundStyle(Color.accaPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
                }

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .sheet(isPresented: $showingSubmitLeg, onDismiss: {
                Task { await loadCurrentGameWeekLegs() }
            }) {
                if let currentGameWeekId, let currentMemberId {
                    SubmitLegView(gameWeekId: currentGameWeekId, memberId: currentMemberId)
                        .environmentObject(appState)
                }
            }
            .task {
                await checkIfManager()
                await loadCurrentMember()
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
        let fixture = leg.id.flatMap { fixtures[$0] }
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
        guard let home = fixture.homeGoals, let away = fixture.awayGoals else {
            return "vs"
        }
        return "\(home) - \(away)"
    }

    private func statusLabel(for fixture: FootballAPIService.Fixture) -> String {
        if fixture.isLive { return "Live" }
        if fixture.isFinished { return "Full time" }
        return "Kickoff soon"
    }

    private func statusColor(for fixture: FootballAPIService.Fixture) -> Color {
        if fixture.isLive { return Color.accaLive }
        if fixture.isFinished { return Color.accaTextSecondary }
        return Color.accaPending
    }

    private func checkIfManager() async {
        guard let teamId = appState.currentUser?.teamIds.first,
              let userId = appState.currentUser?.id else { return }
        if let team = try? await FirebaseService.shared.fetchTeam(teamId: teamId) {
            isManager = team.managerId == userId
        }
    }

    private func loadCurrentMember() async {
        guard let teamId = appState.currentUser?.teamIds.first,
              let userId = appState.currentUser?.id else { return }
        if let member = try? await FirebaseService.shared.fetchMember(teamId: teamId, userId: userId) {
            currentMemberId = member.id
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
                currentGameWeekId = nil
                isLoading = false
                return
            }

            currentGameWeekId = gameWeekId
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
            guard let legId = leg.id, let sportmonksId = leg.sportmonksFixtureId else { continue }
            if let fetched = try? await FootballAPIService.shared.fetchFixture(id: sportmonksId) {
                fixtures[legId] = fetched
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
