//
//  AwardsEngine.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//

import Foundation

enum Achievement: String, CaseIterable, Codable {
    case firstBlood = "First Blood"
    case hatTrick = "Hat-Trick"
    case onFire = "On Fire"
    case unstoppable = "Unstoppable"
    case underdog = "Underdog"
    case longShotLegend = "Long Shot Legend"
    case centuryClub = "Century Club"
    case ironWill = "Iron Will"
    case comebackKid = "Comeback Kid"
    case allRounder = "All-Rounder"

    var description: String {
        switch self {
        case .firstBlood: return "Won your first ever leg"
        case .hatTrick: return "3 winning legs in a row"
        case .onFire: return "5 winning legs in a row"
        case .unstoppable: return "10 winning legs in a row"
        case .underdog: return "Won a leg at odds of 5/1 or bigger"
        case .longShotLegend: return "Won a leg at odds of 10/1 or bigger"
        case .centuryClub: return "Reached 100 base points in a season"
        case .ironWill: return "Submitted a leg in every gameweek this season"
        case .comebackKid: return "Won a leg right after a 5-leg losing streak"
        case .allRounder: return "Placed a leg of every bet type at least once"
        }
    }

    var emoji: String {
        switch self {
        case .firstBlood: return "🩸"
        case .hatTrick: return "🎩"
        case .onFire: return "🔥"
        case .unstoppable: return "🚀"
        case .underdog: return "🐶"
        case .longShotLegend: return "🎯"
        case .centuryClub: return "💯"
        case .ironWill: return "🛡️"
        case .comebackKid: return "🔁"
        case .allRounder: return "🎓"
        }
    }
}

enum AwardsEngine {

    static func evaluate(memberId: String, legs: [AccumulatorLeg], totalGameWeeks: Int) -> [Achievement] {
        let mine = legs
            .filter { $0.memberId == memberId }
            .sorted { $0.submittedAt < $1.submittedAt }
        let settled = mine.filter { $0.outcome == .won || $0.outcome == .lost }

        var unlocked: Set<Achievement> = []

        if settled.contains(where: { $0.outcome == .won }) {
            unlocked.insert(.firstBlood)
        }

        var runningWin = 0
        var runningLoss = 0
        for leg in settled {
            if leg.outcome == .won {
                if runningLoss >= 5 { unlocked.insert(.comebackKid) }
                runningLoss = 0
                runningWin += 1
                if runningWin >= 3 { unlocked.insert(.hatTrick) }
                if runningWin >= 5 { unlocked.insert(.onFire) }
                if runningWin >= 10 { unlocked.insert(.unstoppable) }
            } else {
                runningWin = 0
                runningLoss += 1
            }
        }

        for leg in settled where leg.outcome == .won {
            let fraction = leg.decimalOddsAtSelection - 1.0
            if fraction >= 5.0 { unlocked.insert(.underdog) }
            if fraction >= 10.0 { unlocked.insert(.longShotLegend) }
        }

        let totalBasePoints = settled.reduce(0) { $0 + $1.basePoints }
        if totalBasePoints >= 100 { unlocked.insert(.centuryClub) }

        let weeksPlayed = Set(mine.map { $0.gameWeekId }).count
        if totalGameWeeks > 0 && weeksPlayed >= totalGameWeeks { unlocked.insert(.ironWill) }

        let betTypesUsed = Set(mine.map { $0.betType })
        if betTypesUsed.count == BetType.allCases.count { unlocked.insert(.allRounder) }

        return Array(unlocked)
    }
}
