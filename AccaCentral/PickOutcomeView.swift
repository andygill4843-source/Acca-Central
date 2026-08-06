//
//  PickOutcomeView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//

import SwiftUI

struct PickOutcomeView: View {
    let event: OddsAPIService.OddsEvent
    let league: OddsAPIService.SoccerLeague
    let gameWeekId: String
    let memberId: String
    let teamId: String
    var onSubmitted: () -> Void

    @State private var fullEvent: OddsAPIService.OddsEvent?
    @State private var isLoadingOdds = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private struct PricedOutcome {
        let name: String
        let point: Double?
        let bestPrice: Double
        let bestBookmaker: String
        let allPrices: [String: Double]   // every bookmaker offering this exact selection
        let allLinks: [String: String]
    }

    private static let marketConfig: [(key: String, title: String, betType: BetType)] = [
        ("h2h", "Match Winner", .matchWinner),
        ("totals", "Over/Under", .overUnderGoals),
        ("btts", "Both Teams to Score", .bothTeamsToScore),
        ("draw_no_bet", "Draw No Bet", .drawNoBet),
        ("spreads", "Handicap", .handicap)
    ]

    var body: some View {
        Group {
            if isLoadingOdds {
                ProgressView()
            } else {
                List {
                    ForEach(Self.marketConfig, id: \.key) { config in
                        if let options = bestOutcomes(forMarketKey: config.key), !options.isEmpty {
                            Section(config.title) {
                                ForEach(Array(options.enumerated()), id: \.offset) { _, outcome in
                                    optionRow(outcome: outcome, betType: config.betType)
                                }
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Color.accaLoss)
                    }
                }
            }
        }
        .navigationTitle("\(event.homeTeam) vs \(event.awayTeam)")
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                ProgressView()
            }
        }
        .task {
            await loadFullOdds()
        }
    }

    private func loadFullOdds() async {
        do {
            fullEvent = try await OddsAPIService.shared.fetchEventOdds(league: league, eventId: event.id)
        } catch {
            fullEvent = event
        }
        isLoadingOdds = false
    }

    private func bestOutcomes(forMarketKey key: String) -> [PricedOutcome]? {
        guard let source = fullEvent else { return nil }

        var prices: [String: [String: Double]] = [:]   // groupKey -> [bookmaker: price]
        var links: [String: [String: String]] = [:]    // groupKey -> [bookmaker: link]
        var names: [String: (name: String, point: Double?)] = [:]

        for bookmaker in source.bookmakers {
            guard let market = bookmaker.markets.first(where: { $0.key == key }) else { continue }
            for outcome in market.outcomes {
                let groupKey = "\(outcome.name)|\(outcome.point ?? 0)"
                names[groupKey] = (outcome.name, outcome.point)
                prices[groupKey, default: [:]][bookmaker.title] = outcome.price
                if let link = outcome.link ?? market.link ?? bookmaker.link {
                    links[groupKey, default: [:]][bookmaker.title] = link
                }
            }
        }

        return names.keys.compactMap { groupKey -> PricedOutcome? in
            guard let priceMap = prices[groupKey], let meta = names[groupKey] else { return nil }
            guard let best = priceMap.max(by: { $0.value < $1.value }) else { return nil }
            return PricedOutcome(
                name: meta.name,
                point: meta.point,
                bestPrice: best.value,
                bestBookmaker: best.key,
                allPrices: priceMap,
                allLinks: links[groupKey] ?? [:]
            )
        }
        .sorted { $0.name < $1.name }
    }

    private func displayName(for outcome: PricedOutcome, betType: BetType) -> String {
        switch betType {
        case .overUnderGoals:
            let pointText = outcome.point.map { " \($0)" } ?? ""
            return "\(outcome.name)\(pointText) goals"
        case .handicap:
            let pointText = outcome.point.map { $0 > 0 ? " +\($0)" : " \($0)" } ?? ""
            return "\(outcome.name)\(pointText)"
        default:
            return outcome.name
        }
    }

    private func optionRow(outcome: PricedOutcome, betType: BetType) -> some View {
        let name = displayName(for: outcome, betType: betType)
        return VStack(alignment: .leading, spacing: 4) {
            Button {
                submit(selectionDescription: "\(name) — \(event.homeTeam) vs \(event.awayTeam)", betType: betType, outcome: outcome)
            } label: {
                HStack {
                    Text(name)
                    Spacer()
                    Text(String(format: "%.2f", outcome.bestPrice))
                        .foregroundStyle(Color.accaTextSecondary)
                }
            }
            .foregroundStyle(Color.accaTextPrimary)

            Text("Best price: \(outcome.bestBookmaker) · \(outcome.allPrices.count) bookmakers compared")
                .font(.system(size: 11))
                .foregroundStyle(Color.accaTextSecondary)
        }
    }

    private func submit(selectionDescription: String, betType: BetType, outcome: PricedOutcome) {
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
                decimalOddsAtSelection: outcome.bestPrice,
                bookmaker: outcome.bestBookmaker,
                bookmakerPrices: outcome.allPrices,
                bookmakerLinks: outcome.allLinks,
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
