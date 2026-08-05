//
//  MainTabView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            LeagueTableView()
                .tabItem { Label("Table", systemImage: "list.number") }

            LiveAccumulatorView()
                .tabItem { Label("Live", systemImage: "dot.radiowaves.left.and.right") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            AchievementsView()
                .tabItem { Label("Awards", systemImage: "trophy") }
        }
        .tint(Color.accaGold)
    }
}