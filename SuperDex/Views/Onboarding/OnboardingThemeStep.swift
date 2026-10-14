//
//  OnboardingThemeStep.swift
//  SuperDex
//

import SwiftUI

struct OnboardingThemeStep: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    let accent: Color
    var isReturning = false
    let onBack: () -> Void
    let onDone: () -> Void

    private var selectedIndex: Int {
        viewModel.profile.themeIndex
    }

    private var previewCard: ProfileCard {
        viewModel.profile.asProfileCard
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                    .padding(.top, 16)

                // Same sizing as the Profile tab's hero card.
                ProfileCardView(profile: previewCard, showsShadow: false, showsEmptyLinks: true)
                    .heroCardFrame(containerPadding: 20)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.35), value: selectedIndex)

                formSection(title: "CARD THEME", required: true) {
                    themeGrid
                }

                HStack(spacing: 14) {
                    if !isReturning {
                        Button(action: onBack) {
                            Text("Back")
                                .font(.gilroy(.semiBold, size: 17))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }

                    Button(action: onDone) {
                        Text(isReturning ? "Continue" : "Create My Card")
                            .font(.gilroy(.semiBold, size: 17))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background {
                                Capsule().fill(.white)
                            }
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isReturning ? "Welcome Back" : "Choose Your Theme")
                .font(.gilroy(.bold, size: 26))
                .foregroundStyle(.white)

            Text(isReturning
                 ? "Keep your card's theme or pick a new one. You can change it anytime."
                 : "Pick a card theme that represents you. You can change it anytime.")
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Section Helper

    private func formSection<Content: View>(
        title: String,
        required: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.gilroy(.semiBold, size: 11))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.55))

                if required {
                    Text("•  REQUIRED")
                        .font(.gilroy(.semiBold, size: 10))
                        .tracking(1.2)
                        .foregroundStyle(accent.opacity(0.95))
                }

                Spacer()
            }
            .padding(.horizontal, 4)

            content()
        }
    }

    // MARK: - Theme Grid

    private var themeGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(CardTheme.themes.enumerated()), id: \.offset) { index, theme in
                themeCell(theme: theme, index: index)
            }
        }
        .padding(16)
        .background(fieldBackground)
    }

    private func themeCell(theme: CardTheme, index: Int) -> some View {
        let isSelected = selectedIndex == index

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.profile.themeIndex = index
            }
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: theme.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? accent : .white.opacity(0.12),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
                    .scaleEffect(isSelected ? 1.05 : 1.0)

                Text(theme.name)
                    .font(.gilroy(.semiBold, size: 11))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Field Background

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
    }
}
