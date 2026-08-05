//
//  ScoringEngine.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//

import Foundation

struct LeagueTableEntry: Identifiable {
    var id: String { memberId }
    var memberId: String
    var displayName: String

    var totalBasePoints: Int
    var totalWeightedPoints: Double

    var legsPlayed: Int
    var legsWon: Int
    var winRate: Double { legsPlayed == 0 ? 0 : Double(legsWon) / Double(legsPlayed) }

    var currentStreak: Int
    var longestWinStreak: Int

    var favoriteBetType: BetType?
    var biggestWinOdds: AccumulatorLeg?
}

enum ScoringEngine {

    static func buildLeagueTable(members: [Member], legs: [AccumulatorLeg]) -> [LeagueTableEntry] {
        let grouped = Dictionary(grouping: legs, by: { $0.memberId })

        let entries: [LeagueTableEntry] = members.map { member in
            let memberId = member.id ?? member.userId
            let memberLegs = grouped[memberId] ?? []

            let settled = memberLegs
                .filter { $0.outcome == .won || $0.outcome == .lost }
                .sorted { $0.submittedAt < $1.submittedAt }

            let streaks = computeStreaks(settledLegs: settled)
            let favoriteBetType = mostCommonBetType(in: memberLegs)
            let biggestWin = settled
                .filter { $0.outcome == .won }
                .max { $0.decimalOddsAtSelection < $1.decimalOddsAtSelection }

            return LeagueTableEntry(
                memberId: memberId,
                displayName: member.displayName,
                totalBasePoints: settled.reduce(0) { $0 + $1.basePoints },
                totalWeightedPoints: settled.reduce(0) { $0 + $1.weightedPoints },
                legsPlayed: settled.count,
                legsWon: settled.filter { $0.outcome == .won }.count,
                currentStreak: streaks.current,
                longestWinStreak: streaks.longestWin,
                favoriteBetType: favoriteBetType,
                biggestWinOdds: biggestWin
            )
        }

        return entries.sorted {
            if $0.totalBasePoints != $1.totalBasePoints {
                return $0.totalBasePoints > $1.totalBasePoints
            }
            if $0.totalWeightedPoints != $1.totalWeightedPoints {
                return $0.totalWeightedPoints > $1.totalWeightedPoints
            }
            return $0.winRate > $1.winRate
        }
    }

    static func computeStreaks(settledLegs: [AccumulatorLeg]) -> (current: Int, longestWin: Int) {
        guard !settledLegs.isEmpty else { return (0, 0) }

        var longestWin = 0
        var runningWin = 0
        for leg in settledLegs {
            if leg.outcome == .won {
                runningWin += 1
                longestWin = max(longestWin, runningWin)
            } else {
                runningWin = 0
            }
        }

        var i = settledLegs.count - 1
        let lastOutcome = settledLegs[i].outcome
        var trailing = 0
        while i >= 0, settledLegs[i].outcome == lastOutcome {
            trailing += 1
            i -= 1
        }
        let current = lastOutcome == .won ? trailing : -trailing

        return (current, longestWin)
    }

    static func mostCommonBetType(in legs: [AccumulatorLeg]) -> BetType? {
        guard !legs.isEmpty else { return nil }
        let counts = Dictionary(grouping: legs, by: { $0.betType }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    static func betTypePopularity(legs: [AccumulatorLeg]) -> [(betType: BetType, count: Int)] {
        let counts = Dictionary(grouping: legs, by: { $0.betType }).mapValues { $0.count }
        return counts
            .map { (betType: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}
