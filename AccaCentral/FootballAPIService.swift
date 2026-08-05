//
//  FootballAPIService.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import Foundation

final class FootballAPIService {
    static let shared = FootballAPIService()
    private let baseURL = "https://api.football-data.org/v4"
    private let apiKey = "YOUR_API_KEY"

    private init() {}

    struct Fixture: Codable, Identifiable {
        let id: Int
        let homeTeam: TeamRef
        let awayTeam: TeamRef
        let utcDate: Date
        let status: String
        let score: Score

        struct TeamRef: Codable { let name: String }
        struct Score: Codable {
            let winner: String?
            let fullTime: FullTime
            struct FullTime: Codable { let home: Int?; let away: Int? }
        }
    }

    private struct FixturesResponse: Codable { let matches: [Fixture] }

    func fetchFixtures(competitionCode: String, from: Date, to: Date) async throws -> [Fixture] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var components = URLComponents(string: "\(baseURL)/competitions/\(competitionCode)/matches")!
        components.queryItems = [
            URLQueryItem(name: "dateFrom", value: formatter.string(from: from)),
            URLQueryItem(name: "dateTo", value: formatter.string(from: to))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FixturesResponse.self, from: data).matches
    }

    func fetchFixture(id: Int) async throws -> Fixture {
        var request = URLRequest(url: URL(string: "\(baseURL)/matches/\(id)")!)
        request.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Fixture.self, from: data)
    }
}

enum LegSettlementService {
    static func settleMatchWinnerLeg(_ leg: AccumulatorLeg, fixture: FootballAPIService.Fixture) -> LegOutcome {
        guard fixture.status == "FINISHED" else { return .pending }
        guard let winner = fixture.score.winner else { return .void }

        let pickedHome = leg.selectionDescription.localizedCaseInsensitiveContains(fixture.homeTeam.name)
        let pickedAway = leg.selectionDescription.localizedCaseInsensitiveContains(fixture.awayTeam.name)

        switch winner {
        case "HOME_TEAM": return pickedHome ? .won : (pickedAway ? .lost : .pending)
        case "AWAY_TEAM": return pickedAway ? .won : (pickedHome ? .lost : .pending)
        case "DRAW": return leg.selectionDescription.localizedCaseInsensitiveContains("draw") ? .won : .lost
        default: return .pending
        }
    }
}