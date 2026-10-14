//
//  CardTheme.swift
//  HomeScreen
//

import SwiftUI

struct CardTheme: Hashable {
    let name: String
    let gradientColors: [Color]
    let accentColor: Color

    static let aurora = CardTheme(
        name: "Aurora",
        gradientColors: [Color(.systemIndigo), .blue, .purple],
        accentColor: .white
    )

    static let glacier = CardTheme(
        name: "Glacier",
        gradientColors: [
            Color(red: 0.12, green: 0.58, blue: 0.88),
            Color(red: 0.06, green: 0.32, blue: 0.68),
            Color(red: 0.03, green: 0.13, blue: 0.34)
        ],
        accentColor: Color(red: 0.55, green: 0.85, blue: 0.98)
    )

    static let coral = CardTheme(
        name: "Coral",
        gradientColors: [.orange, .pink, .purple],
        accentColor: .orange
    )

    static let forest = CardTheme(
        name: "Forest",
        gradientColors: [
            Color(red: 0.16, green: 0.68, blue: 0.45),
            Color(red: 0.06, green: 0.45, blue: 0.30),
            Color(red: 0.03, green: 0.20, blue: 0.14)
        ],
        accentColor: Color(red: 0.45, green: 0.95, blue: 0.70)
    )

    static let twilight = CardTheme(
        name: "Twilight",
        gradientColors: [.purple, .indigo, Color(red: 0.15, green: 0.05, blue: 0.3)],
        accentColor: .purple
    )

    static let ember = CardTheme(
        name: "Ember",
        gradientColors: [.red, Color(red: 0.6, green: 0, blue: 0.1), .black],
        accentColor: .red
    )

    static let sunset = CardTheme(
        name: "Sunset",
        gradientColors: [
            Color(red: 0.98, green: 0.52, blue: 0.18),
            Color(red: 0.82, green: 0.22, blue: 0.28),
            Color(red: 0.38, green: 0.08, blue: 0.26)
        ],
        accentColor: Color(red: 1.0, green: 0.78, blue: 0.40)
    )

    static let ocean = CardTheme(
        name: "Ocean",
        gradientColors: [
            Color(red: 0.0, green: 0.7, blue: 0.78),
            Color(red: 0.0, green: 0.42, blue: 0.62),
            Color(red: 0.04, green: 0.13, blue: 0.32)
        ],
        accentColor: .teal
    )

    static let rose = CardTheme(
        name: "Rose",
        gradientColors: [
            Color(red: 0.95, green: 0.42, blue: 0.58),
            Color(red: 0.72, green: 0.22, blue: 0.48),
            Color(red: 0.36, green: 0.08, blue: 0.28)
        ],
        accentColor: Color(red: 1.0, green: 0.75, blue: 0.82)
    )

    static let onyx = CardTheme(
        name: "Onyx",
        gradientColors: [
            Color(red: 0.18, green: 0.18, blue: 0.2),
            Color(red: 0.08, green: 0.08, blue: 0.1),
            .black
        ],
        accentColor: Color(white: 0.85)
    )

    static let superDex = CardTheme(
        name: "SuperDex",
        gradientColors: [
            .indigo,
            Color(red: 0.30, green: 0.30, blue: 0.80),
            Color(red: 0.18, green: 0.18, blue: 0.55)
        ],
        accentColor: .indigo
    )

    static let mattr = CardTheme(
        name: "Mattr",
        gradientColors: [
            Color(red: 0.294, green: 0.275, blue: 0.859), // #4B46DB
            Color(red: 0.278, green: 0.259, blue: 0.808), // #4742CE
            Color(red: 0.243, green: 0.227, blue: 0.710), // #3E3AB5
            Color(red: 0.192, green: 0.180, blue: 0.561), // #312E8F
            Color(red: 0.102, green: 0.086, blue: 0.502)  // #1A1680
        ],
        accentColor: Color(red: 0.294, green: 0.275, blue: 0.859)
    )

    static let themes: [CardTheme] = [
        //.mattr,
        .superDex,
        .onyx,
        //.aurora,
        .glacier,
        .coral,
        .forest,
        .twilight,
        .ember,
        .sunset,
        .ocean,
        .rose,
        
        
    ]

    static func named(_ name: String) -> CardTheme? {
        themes.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
