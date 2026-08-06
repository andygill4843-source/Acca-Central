//
//  FixtureMatchingService.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import Foundation

/// Bridges The Odds API's fixture (used when a member picks a leg) to its
/// Sportmonks equivalent (used for live scores). The two providers don't
/// share an ID scheme, so this does a best-effort match by kickoff date and
/// team name at the moment a leg is submitted.
enum FixtureMatchingService {
    static func resolveSportmonksFixtureId(homeTeam: String, awayTeam: String, kickoff: Date) async -> Int? {
        guard let fixtures = try? await FootballAPIService.shared.fetchFixtures(onDate: kickoff) else {
            return nil
        }
        guard let match = fixtures.first(where: {
            ($0.homeTeamName.localizedCaseInsensitiveContains(homeTeam) || homeTeam.localizedCaseInsensitiveContains($0.homeTeamName)) &&
            ($0.awayTeamName.localizedCaseInsensitiveContains(awayTeam) || awayTeam.localizedCaseInsensitiveContains($0.awayTeamName))
        }) else {
            return nil
        }
        return match.id
    }
}