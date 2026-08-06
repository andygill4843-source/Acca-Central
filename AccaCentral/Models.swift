//
//  Models.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//

import Foundation
import FirebaseFirestore

// MARK: - Team

struct Team: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var managerId: String
    var memberIds: [String]
    var inviteCode: String
    var createdAt: Date
    var season: String
}

// MARK: - User

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var displayName: String
    var email: String
    var teamIds: [String]
    var fcmToken: String?
    var createdAt: Date
}

// MARK: - Member

struct Member: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var displayName: String
    var teamId: String
    var joinedAt: Date
}

// MARK: - GameWeek

struct GameWeek: Identifiable, Codable {
    @DocumentID var id: String?
    var teamId: String
    var weekNumber: Int
    var startDate: Date
    var endDate: Date
    var isSettled: Bool
    var selectedBookmaker: String?
    var combinedOdds: Double?
}

// MARK: - Bet types & outcomes

enum LegOutcome: String, Codable {
    case pending, won, lost, void
}

enum BetType: String, Codable, CaseIterable {
    case matchWinner = "Match Winner"
    case bothTeamsToScore = "Both Teams to Score"
    case overUnderGoals = "Over/Under Goals"
    case drawNoBet = "Draw No Bet"
    case handicap = "Handicap"
    case correctScore = "Correct Score"
    case anytimeScorer = "Anytime Goalscorer"
    case doubleChance = "Double Chance"
    case other = "Other"
}

// MARK: - AccumulatorLeg

struct AccumulatorLeg: Identifiable, Codable {
    @DocumentID var id: String?
    var gameWeekId: String
    var teamId: String
    var memberId: String

    var fixtureId: String
    var fixtureDescription: String
    var kickoff: Date

    var betType: BetType
    var selectionDescription: String

    var decimalOddsAtSelection: Double
    var bookmaker: String
    var bookmakerPrices: [String: Double]   // every bookmaker's price for this exact selection
    var bookmakerLinks: [String: String]    // bookmaker -> betslip link, where one exists
    var sportmonksFixtureId: Int?   // resolved at submission time — nil if no confident match found

    var outcome: LegOutcome
    var submittedAt: Date

    var basePoints: Int {
        outcome == .won ? 3 : 0
    }

    var weightedPoints: Double {
        guard outcome == .won else { return 0 }
        return (decimalOddsAtSelection - 1.0) * 3.0
    }
}
