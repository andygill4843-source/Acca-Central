//
//  AccaCentralApp.swift
//  AccaCentral
//
//  Created by Andy Gill on 04/08/2026.
//

import SwiftUI
import FirebaseCore

@main
struct AccaCentralApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
