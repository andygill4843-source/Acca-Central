//
//  PickOutcomeView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct PickOutcomeView: View {
    let event: OddsAPIService.OddsEvent
    let gameWeekId: String
    let memberId: String
    let teamId: String
    var onSubmitted: () -> Void

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private struct PricedOutcome { let name: String; let price: Double; let bookmaker: String }

    var body: some View {
        List {
            if let matchWinnerOptions {
                Section("Match Winner") {
                    ForEach(matchWinnerOptions, id: \.name) { outcome in
                        optionRow(name: outcome.name, price: outcome.price, bookmaker: outcome.bookmaker, betType: .matchWinner)
                    }
                }
            }

            if let totalsOptions {
                Section("Over/Under") {
                    ForEach(totalsOptions, id: \.name) { outcome in
                        optionRow(name: outcome.name, price: outcome.price, bookmaker: outcome.bookmaker, betType: .overUnderGoals)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(Color.accaLoss)
            }
        }
        .navigationTitle("\(event.homeTeam) vs \(event.awayTeam)")
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                ProgressView()
            }
        }
    }

    private var matchWinnerOptions: [PricedOutcome]? {
        for bookmaker in event.bookmakers {
            if let market = bookmaker.markets.first(where: { $0.key == "h2h" }) {
                return market.outcomes.map { PricedOutcome(name: $0.name, price: $0.price, bookmaker: bookmaker.title) }
            }
        }
        return nil
    }

    private var totalsOptions: [PricedOutcome]? {
        for bookmaker in event.bookmakers {
            if let market = bookmaker.markets.first(where: { $0.key == "totals" }) {
                return market.outcomes.map { outcome in
                    let pointText = outcome.point.map { " \($0)" } ?? ""
                    return PricedOutcome(name: "\(outcome.name)\(pointText) goals", price: outcome.price, bookmaker: bookmaker.title)
                }
            }
        }
        return nil
    }

    private func optionRow(name: String, price: Double, bookmaker: String, betType: BetType) -> some View {
        Button {
            submit(selectionDescription: "\(name) — \(event.homeTeam) vs \(event.awayTeam)", betType: betType, price: price, bookmaker: bookmaker)
        } label: {
            HStack {
                Text(name)
                Spacer()
                Text(String(format: "%.2f", price))
                    .foregroundStyle(Color.accaTextSecondary)
            }
        }
        .foregroundStyle(Color.accaTextPrimary)
    }

    private func submit(selectionDescription: String, betType: BetType, price: Double, bookmaker: String) {
        isSubmitting = true
        errorMessage = nil

        Task {
            let sportmonksId = await FixtureMatchingService.resolveSportmonksFixtureId(
                homeTeam: event.homeTeam,
                awayTeam: event.awayTeam,
                kickoff: event.commenceTime
            )

            let leg = AccumulatorLeg(
                id: nil,
                gameWeekId: gameWeekId,
                teamId: teamId,
                memberId: memberId,
                fixtureId: event.id,
                fixtureDescription: "\(event.homeTeam) vs \(event.awayTeam)",
                kickoff: event.commenceTime,
                betType: betType,
                selectionDescription: selectionDescription,
                decimalOddsAtSelection: price,
                bookmaker: bookmaker,
                sportmonksFixtureId: sportmonksId,
                outcome: .pending,
                submittedAt: Date()
            )

            do {
                try await FirebaseService.shared.submitLeg(leg)
                await MainActor.run {
                    isSubmitting = false
                    onSubmitted()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
