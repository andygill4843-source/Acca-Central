//
//  GameWeekSetupView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct GameWeekSetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var weekNumber: Int = 1
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60 * 60 * 24 * 3) // default 3-day window
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Gameweek") {
                    Stepper("Week \(weekNumber)", value: $weekNumber, in: 1...50)
                }

                Section("Window") {
                    DatePicker("First kickoff", selection: $startDate, in: Date()...Date().addingTimeInterval(14 * 24 * 60 * 60), displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Deadline / last match", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accaLoss)
                }

                Section {
                    Button(action: create) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Create gameweek")
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("New Gameweek")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await suggestNextWeekNumber()
            }
        }
    }

    private func suggestNextWeekNumber() async {
        guard let teamId = appState.currentUser?.teamIds.first else { return }
        if let existing = try? await FirebaseService.shared.fetchGameWeeks(teamId: teamId) {
            weekNumber = (existing.map { $0.weekNumber }.max() ?? 0) + 1
        }
    }

    private func create() {
        guard let teamId = appState.currentUser?.teamIds.first else { return }
        guard endDate > startDate else {
            errorMessage = "Deadline must be after the first kickoff."
            return
        }
        guard startDate <= Date().addingTimeInterval(14 * 24 * 60 * 60) else {
            errorMessage = "Gameweeks can only be set up within the next two weeks — bookmaker odds aren't posted further ahead than that."
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                let existing = try await FirebaseService.shared.fetchGameWeeks(teamId: teamId)
                if existing.contains(where: { !$0.isSettled }) {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "There's already an active gameweek. End it before creating a new one."
                    }
                    return
                }

                let gameWeek = GameWeek(
                    id: nil,
                    teamId: teamId,
                    weekNumber: weekNumber,
                    startDate: startDate,
                    endDate: endDate,
                    isSettled: false
                )
                _ = try await FirebaseService.shared.createGameWeek(gameWeek)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
