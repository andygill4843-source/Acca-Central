//
//  AccumulatorSummaryView.swift
//  AccaCentral
//
//  Created by Andy Gill on 06/08/2026.
//


import SwiftUI

struct AccumulatorSummaryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let gameWeek: GameWeek

    @State private var legs: [AccumulatorLeg] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false

    private struct BookmakerOption: Identifiable {
        var id: String { bookmaker }
        let bookmaker: String
        let combinedOdds: Double
        let legLinks: [(leg: AccumulatorLeg, link: String?)]
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(Color.accaLoss)
                } else if legs.isEmpty {
                    Text("No legs submitted yet.")
                        .foregroundStyle(Color.accaTextSecondary)
                } else {
                    List {
                        if let selected = gameWeek.selectedBookmaker {
                            Section("Selected bookmaker") {
                                Text(selected)
                                    .font(.system(size: 15, weight: .semibold))
                                if let odds = gameWeek.combinedOdds {
                                    Text(String(format: "Combined odds: %.2f", odds))
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.accaTextSecondary)
                                }
                            }
                        }

                        Section("Compare bookmakers") {
                            if bookmakerOptions.isEmpty {
                                Text("No single bookmaker covers every leg of this accumulator — legs may need placing across multiple bookmakers.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.accaTextSecondary)
                            } else {
                                ForEach(bookmakerOptions) { option in
                                    bookmakerRow(option)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Best Odds")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    /// Only bookmakers present on EVERY leg qualify — you can't place a
    /// single accumulator bet with a bookmaker who's missing one leg of it.
    private var bookmakerOptions: [BookmakerOption] {
        guard !legs.isEmpty else { return [] }

        let bookmakerSets = legs.map { Set($0.bookmakerPrices.keys) }
        guard let firstSet = bookmakerSets.first else { return [] }
        let common = bookmakerSets.dropFirst().reduce(firstSet) { $0.intersection($1) }

        return common.map { bookmaker in
            let combined = legs.reduce(1.0) { partial, leg in
                partial * (leg.bookmakerPrices[bookmaker] ?? 1.0)
            }
            let links = legs.map { (leg: $0, link: $0.bookmakerLinks[bookmaker]) }
            return BookmakerOption(bookmaker: bookmaker, combinedOdds: combined, legLinks: links)
        }
        .sorted { $0.combinedOdds > $1.combinedOdds }
    }

    private func bookmakerRow(_ option: BookmakerOption) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.bookmaker)
                        .font(.system(size: 15, weight: .medium))
                    Text(String(format: "Combined odds: %.2f", option.combinedOdds))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accaTextSecondary)
                }
                Spacer()
                Button(gameWeek.selectedBookmaker == option.bookmaker ? "Selected" : "Select") {
                    select(option)
                }
                .font(.system(size: 13, weight: .medium))
                .disabled(isSaving || gameWeek.selectedBookmaker == option.bookmaker)
            }

            ForEach(option.legLinks, id: \.leg.id) { pair in
                if let linkString = pair.link, let url = URL(string: linkString) {
                    Link("\(pair.leg.fixtureDescription): open bet →", destination: url)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accaGold)
                } else {
                    Text("\(pair.leg.fixtureDescription): no direct link")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.accaTextSecondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func load() async {
        guard let teamId = appState.currentUser?.teamIds.first, let gameWeekId = gameWeek.id else {
            errorMessage = "No gameweek found."
            isLoading = false
            return
        }
        do {
            legs = try await FirebaseService.shared.fetchLegs(teamId: teamId, gameWeekId: gameWeekId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func select(_ option: BookmakerOption) {
        guard let gameWeekId = gameWeek.id else { return }
        isSaving = true
        Task {
            try? await FirebaseService.shared.setGameWeekBookmaker(gameWeekId: gameWeekId, bookmaker: option.bookmaker, combinedOdds: option.combinedOdds)
            isSaving = false
            dismiss()
        }
    }
}