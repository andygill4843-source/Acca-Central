//
//  OddsAPIService.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import Foundation

final class OddsAPIService {
    static let shared = OddsAPIService()
    private let baseURL = "https://api.the-odds-api.com/v4"
    private let apiKey = "ff585ca95c3be67ff9e85dd16ad3e75d"

    private init() {}

    enum SoccerLeague: String, CaseIterable {
        case premierLeague = "soccer_epl"
        case championsLeague = "soccer_uefa_champs_league"
        case laLiga = "soccer_spain_la_liga"
        case serieA = "soccer_italy_serie_a"
        case bundesliga = "soccer_germany_bundesliga"
        case ligue1 = "soccer_france_ligue_one"
    }

    struct OddsEvent: Codable, Identifiable {
        let id: String
        let sportKey: String
        let commenceTime: Date
        let homeTeam: String
        let awayTeam: String
        let bookmakers: [Bookmaker]

        enum CodingKeys: String, CodingKey {
            case id
            case sportKey = "sport_key"
            case commenceTime = "commence_time"
            case homeTeam = "home_team"
            case awayTeam = "away_team"
            case bookmakers
        }
    }

    struct Bookmaker: Codable {
        let key: String
        let title: String
        let markets: [Market]
    }

    struct Market: Codable {
        let key: String
        let outcomes: [Outcome]
    }

    struct Outcome: Codable {
        let name: String
        let price: Double
        let point: Double?
    }

    func fetchOdds(league: SoccerLeague, markets: [String] = ["h2h", "totals"]) async throws -> [OddsEvent] {
        var components = URLComponents(string: "\(baseURL)/sports/\(league.rawValue)/odds")!
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "regions", value: "uk"),
            URLQueryItem(name: "markets", value: markets.joined(separator: ",")),
            URLQueryItem(name: "oddsFormat", value: "decimal")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([OddsEvent].self, from: data)
    }

    func bestPrice(for outcomeName: String, marketKey: String, in event: OddsEvent) -> (price: Double, bookmaker: String)? {
        for bookmaker in event.bookmakers {
            guard let market = bookmaker.markets.first(where: { $0.key == marketKey }) else { continue }
            if let outcome = market.outcomes.first(where: { $0.name.localizedCaseInsensitiveCompare(outcomeName) == .orderedSame }) {
                return (outcome.price, bookmaker.title)
            }
        }
        return nil
    }
}
