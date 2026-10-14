//
//  OnboardingView.swift
//  SuperDex
//

import SwiftUI

struct OnboardingView: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    @State private var step: Step

    enum Step { case profile, theme, ready }

    /// When set, called at the end instead of completing (and saving)
    /// onboarding — used by DebugFlags.onboardingPreview.
    private let onFinish: (() -> Void)?
    /// An existing account signing back in: no profile step to go back to.
    private let isReturning: Bool

    init(startStep: Step = .profile, isReturning: Bool = false, onFinish: (() -> Void)? = nil) {
        _step = State(initialValue: startStep)
        self.isReturning = isReturning
        self.onFinish = onFinish
    }

    private let accent = Color.indigo

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            switch step {
            case .profile:
                OnboardingProfileStep(accent: accent) {
                    withAnimation(.easeInOut(duration: 0.3)) { step = .theme }
                }
            case .theme:
                OnboardingThemeStep(accent: accent, isReturning: isReturning) {
                    withAnimation(.easeInOut(duration: 0.3)) { step = .profile }
                } onDone: {
                    withAnimation(.easeInOut(duration: 0.4)) { step = .ready }
                }
            case .ready:
                OnboardingCardReadyView(accent: accent) {
                    if let onFinish {
                        onFinish()
                    } else {
                        viewModel.completeOnboarding()
                    }
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)

            RadialGradient(
                colors: [accent.opacity(0.30), .clear],
                center: UnitPoint(x: 0.0, y: 0.0),
                startRadius: 0,
                endRadius: 420
            )

            RadialGradient(
                colors: [accent.opacity(0.18), .clear],
                center: UnitPoint(x: 1.0, y: 0.2),
                startRadius: 0,
                endRadius: 360
            )
        }
    }
}
