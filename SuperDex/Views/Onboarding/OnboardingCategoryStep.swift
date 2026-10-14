//
//  OnboardingCategoryStep.swift
//  SuperDex
//

import SwiftUI

struct OnboardingCategoryStep: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    let accent: Color
    let onBack: () -> Void
    let onNext: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var canContinue: Bool {
        !viewModel.profile.categories.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                    .padding(.top, 16)

                categoryGrid

                Button(action: onNext) {
                    Text("Next")
                        .font(.gilroy(.semiBold, size: 17))
                        .foregroundStyle(canContinue ? .black : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background {
                            // Pure liquid glass until ready, then fills solid white.
                            Capsule().fill(.white.opacity(canContinue ? 1 : 0))
                        }
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                .scaleEffect(canContinue ? 1.0 : 0.97)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: canContinue)
                .disabled(!canContinue)
                .padding(.top, 8)

                Button(action: onBack) {
                    Text("Back")
                        .font(.gilroy(.medium, size: 14))
                        .foregroundStyle(.white.opacity(0.40))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Your Domain")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Domain")
                .font(.gilroy(.bold, size: 26))
                .foregroundStyle(.white)

            Text("Pick the domains you work in — at your company, on the side, or anywhere your interests run. Choose as many as you like.")
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ProfileCategory.allCases) { category in
                let isSelected = viewModel.profile.categories.contains(category)
                Button {
                    toggleCategory(category)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: category.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? accent : .white.opacity(0.55))
                            .frame(width: 22)

                        Text(category.displayName)
                            .font(.gilroy(.semiBold, size: 13))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? accent.opacity(0.7) : .white.opacity(0.10),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleCategory(_ category: ProfileCategory) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if let idx = viewModel.profile.categories.firstIndex(of: category) {
                viewModel.profile.categories.remove(at: idx)
            } else {
                viewModel.profile.categories.append(category)
            }
        }
    }
}
