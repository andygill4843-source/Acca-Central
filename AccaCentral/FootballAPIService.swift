//
//  FootballAPIService.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import Foundation

/// Client for Sportmonks Football API v3, used for live fixture status and
/// scores. Note: Sportmonks fixture IDs are a completely different scheme
/// from The Odds API's event IDs (used in OddsAPIService when a member
/// picks a leg) — there's no shared identifier between the two providers.
/// See FixtureMatchingService for how a leg gets a Sportmonks ID resolved
/// and stored at submission time.
final class FootballAPIService {
    static let shared = FootballAPIService()
    private let baseURL = "https://api.sportmonks.com/v3/football"
    private let apiToken = "hdkhpa8UZkgocItDmHY5rctiXFbqguYweioOEgMHzMTB0iB06V71fAVOE10E" // load from a secrets file, never hardcode for real

    private init() {}

    struct FixtureResponse: Codable { let data: Fixture }
    struct FixtureListResponse: Codable { let data: [Fixture] }

    struct Fixture: Codable, Identifiable {
        let id: Int
        let name: String
        let startingAt: String
        let state: FixtureState
        let participants: [Participant]?
        let scores: [ScoreEntry]?

        struct FixtureState: Codable {
            let id: Int
            let state: String       // e.g. "NS", "LIVE", "HT", "FT"
            let name: String
            let shortName: String
        }

        struct Participant: Codable {
            let id: Int
            let name: String
            let meta: Meta?

            struct Meta: Codable {
                let location: String?   // "home" or "away"
            }
        }

        struct ScoreEntry: Codable {
            let description: String     // "CURRENT" is the one we want
            let score: ScoreDetail

            struct ScoreDetail: Codable {
                let participant: String // "home" or "away"
                let goals: Int
            }
        }

        var homeTeamName: String {
            participants?.first { $0.meta?.location == "home" }?.name ?? "Home"
        }

        var awayTeamName: String {
            participants?.first { $0.meta?.location == "away" }?.name ?? "Away"
        }

        var homeGoals: Int? {
            scores?.first { $0.description == "CURRENT" && $0.score.participant == "home" }?.score.goals
        }

        var awayGoals: Int? {
            scores?.first { $0.description == "CURRENT" && $0.score.participant == "away" }?.score.goals
        }

        var isLive: Bool {
            ["LIVE", "INPLAY_1ST", "INPLAY_2ND", "HT", "ET", "BREAK", "PEN_LIVE", "INT", "SUSP"].contains(state.shortName)
        }

        var isFinished: Bool {
            ["FT", "AET", "FT_PEN", "ABAN", "CANCL"].contains(state.shortName)
        }
    }

    func fetchFixture(id: Int) async throws -> Fixture {
        var components = URLComponents(string: "\(baseURL)/fixtures/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "api_token", value: apiToken),
            URLQueryItem(name: "include", value: "participants;scores;state")
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder.sportmonks.decode(FixtureResponse.self, from: data).data
    }

    /// Fixtures scheduled on a given date — used to match an Odds-API-sourced
    /// fixture to its Sportmonks equivalent by date + team names.
    func fetchFixtures(onDate date: Date) async throws -> [Fixture] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        var components = URLComponents(string: "\(baseURL)/fixtures/date/\(dateString)")!
        components.queryItems = [
            URLQueryItem(name: "api_token", value: apiToken),
            URLQueryItem(name: "include", value: "participants;state")
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder.sportmonks.decode(FixtureListResponse.self, from: data).data
    }
}

extension JSONDecoder {
    static var sportmonks: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
