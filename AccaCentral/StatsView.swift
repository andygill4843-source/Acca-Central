//
//  StatsView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationStack {
            Text("Streaks, popular bet types")
                .foregroundStyle(Color.accaTextSecondary)
                .navigationTitle("Stats")
        }
    }
}

struct AchievementsView: View {
    var body: some View {
        NavigationStack {
            Text("Unlocked achievements grid")
                .foregroundStyle(Color.accaTextSecondary)
                .navigationTitle("Awards")
        }
    }
}