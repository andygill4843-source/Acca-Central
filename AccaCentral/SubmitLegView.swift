//
//  SubmitLegView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct SubmitLegView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let gameWeekId: String
    let memberId: String

    @State private var selectedLeague: OddsAPIService.SoccerLeague = .premierLeague
    @State private var events: [OddsAPIService.OddsEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Competition", selection: $selectedLeague) {
                    Text("Premier League").tag(OddsAPIService.SoccerLeague.premierLeague)
                    Text("Champions League").tag(OddsAPIService.SoccerLeague.championsLeague)
                    Text("La Liga").tag(OddsAPIService.SoccerLeague.laLiga)
                    Text("Serie A").tag(OddsAPIService.SoccerLeague.serieA)
                    Text("Bundesliga").tag(OddsAPIService.SoccerLeague.bundesliga)
                    Text("Ligue 1").tag(OddsAPIService.SoccerLeague.ligue1)
                }
                .pickerStyle(.menu)
                .padding()

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    Text(errorMessage)
                        .foregroundStyle(Color.accaLoss)
                        .padding()
                    Spacer()
                } else if events.isEmpty {
                    Spacer()
                    Text("No upcoming fixtures found for this competition.")
                        .foregroundStyle(Color.accaTextSecondary)
                        .padding()
                    Spacer()
                } else {
                    List(events) { event in
                        NavigationLink {
                            PickOutcomeView(
                                event: event,
                                gameWeekId: gameWeekId,
                                memberId: memberId,
                                teamId: appState.currentUser?.teamIds.first ?? "",
                                onSubmitted: { dismiss() }
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(event.homeTeam) vs \(event.awayTeam)")
                                    .font(.system(size: 15, weight: .medium))
                                Text(event.commenceTime.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.accaTextSecondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Pick your leg")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadEvents() }
            .onChange(of: selectedLeague) { _ in
                Task { await loadEvents() }
            }
        }
    }

    private func loadEvents() async {
        isLoading = true
        errorMessage = nil
        do {
            events = try await OddsAPIService.shared.fetchOdds(league: selectedLeague)
            isLoading = false
        } catch {
            errorMessage = "Couldn't load fixtures/odds."
            isLoading = false
        }
    }
}