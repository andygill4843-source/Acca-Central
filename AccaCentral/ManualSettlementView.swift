//
//  ManualSettlementView.swift
//  AccaCentral
//
//  Created by Andy Gill on 06/08/2026.
//


import SwiftUI

struct ManualSettlementView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var pendingLegs: [AccumulatorLeg] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(Color.accaLoss)
                } else if pendingLegs.isEmpty {
                    Text("Nothing waiting on manual settlement.")
                        .foregroundStyle(Color.accaTextSecondary)
                } else {
                    List(pendingLegs) { leg in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(leg.fixtureDescription)
                                .font(.system(size: 14, weight: .medium))
                            Text(leg.selectionDescription)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.accaTextSecondary)

                            HStack(spacing: 12) {
                                settleButton("Won", outcome: .won, color: Color.accaWin, leg: leg)
                                settleButton("Lost", outcome: .lost, color: Color.accaLoss, leg: leg)
                                settleButton("Void", outcome: .void, color: Color.accaPending, leg: leg)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("\(RoleTitles.teamLeader) Settlement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func settleButton(_ label: String, outcome: LegOutcome, color: Color, leg: AccumulatorLeg) -> some View {
        Button(label) {
            settle(leg: leg, outcome: outcome)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private func load() async {
        guard let teamId = appState.currentUser?.teamIds.first else {
            errorMessage = "No team found."
            isLoading = false
            return
        }
        do {
            let allLegs = try await FirebaseService.shared.fetchLegs(teamId: teamId)
            pendingLegs = allLegs
                .filter { $0.outcome == .pending && $0.kickoff < Date() } // only show ones whose match has started
                .sorted { $0.kickoff < $1.kickoff }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func settle(leg: AccumulatorLeg, outcome: LegOutcome) {
        guard let legId = leg.id else { return }
        Task {
            try? await FirebaseService.shared.updateLegOutcome(legId: legId, outcome: outcome)
            pendingLegs.removeAll { $0.id == legId }
        }
    }
}