//
//  AppBackground.swift
//  SuperDex
//
//  Shared matte-dark background used across the app.
//

import SwiftUI

struct AppBackground: View {
    /// When true the top accent glow is shown. Disable for screens that have
    /// their own theme-colored glow on top of this base.
    var showTopGlow: Bool = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.085, green: 0.090, blue: 0.115),
                    Color(red: 0.040, green: 0.043, blue: 0.058),
                    Color(red: 0.022, green: 0.024, blue: 0.034)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if showTopGlow {
                RadialGradient(
                    colors: [
                        Color(red: 0.20, green: 0.24, blue: 0.34).opacity(0.32),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 420
                )
                .blendMode(.plusLighter)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AppBackground()
}
