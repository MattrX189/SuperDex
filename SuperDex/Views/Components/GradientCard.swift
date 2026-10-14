//
//  GradientCard.swift
//  SuperDex
//
//  The signature layered-gradient card chrome used by GroupCardView
//  (dark blue-gray base, accent corner glows, gradient border, dual
//  shadow, glass on top). Extracted so gig cards and Pro member rows
//  share the exact same look — pass the accent color.
//

import SwiftUI

struct GradientCardModifier: ViewModifier {
    let accent: Color
    var cornerRadius: CGFloat = 26

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(shape)
            .compositingGroup()
            .overlay(border)
            .shadow(color: accent.opacity(0.30), radius: 18, y: 12)
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
            .glassEffect(.regular.interactive(), in: shape)
            .contentShape(shape)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.06, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [accent.opacity(0.40), .clear],
                center: UnitPoint(x: 0.0, y: 0.0),
                startRadius: 0,
                endRadius: 240
            )

            RadialGradient(
                colors: [accent.opacity(0.20), .clear],
                center: UnitPoint(x: 1.0, y: 1.1),
                startRadius: 0,
                endRadius: 200
            )

            RadialGradient(
                colors: [.white.opacity(0.10), .clear],
                center: UnitPoint(x: 0.95, y: 0.05),
                startRadius: 0,
                endRadius: 180
            )
        }
    }

    private var border: some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        accent.opacity(0.55),
                        .white.opacity(0.10),
                        .clear,
                        accent.opacity(0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

extension View {
    /// Applies the GroupCardView-style layered gradient card chrome.
    func gradientCard(accent: Color, cornerRadius: CGFloat = 26) -> some View {
        modifier(GradientCardModifier(accent: accent, cornerRadius: cornerRadius))
    }
}
