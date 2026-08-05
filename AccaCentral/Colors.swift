//
//  Colours.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//

import SwiftUI

extension Color {
    static let accaPrimary = Color(hex: "0F1B3C")
    static let accaSecondary = Color(hex: "1D2E5C")
    static let accaGold = Color(hex: "E8B923")

    static let accaBackground = Color(hex: "F4F4F0")
    static let accaBackgroundDark = Color(hex: "0A1128")
    static let accaCard = Color.white

    static let accaWin = Color(hex: "16A34A")
    static let accaLoss = Color(hex: "DC2626")
    static let accaPending = Color(hex: "6B7280")
    static let accaLive = Color(hex: "E8B923")

    static let accaTextPrimary = Color(hex: "0F1B3C")
    static let accaTextSecondary = Color(hex: "5F5E5A")
}

extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
