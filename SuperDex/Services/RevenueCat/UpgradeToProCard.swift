//
//  UpgradeToProCard.swift
//  SuperDex
//
//  Drop-in upgrade card for SuperDex Pro. Tapping it opens the custom paywall.
//  Renders nothing when the user is already Pro, so it's safe to leave in
//  view hierarchies unconditionally.
//

import SwiftUI

struct UpgradeToProCard: View {
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(UserProfileViewModel.self) private var profileVM
    @State private var showPaywall = false

    private var isPro: Bool { subscription.isPro || profileVM.profile.hasPro }

    var body: some View {
        Group {
            if !isPro {
                Button { showPaywall = true } label: { cardContent }
                    .buttonStyle(.plain)
            }
        }
        .paywallSheet(isPresented: $showPaywall)
    }

    private let accentColor = Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0)

    private var cardContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("SuperDex Pro")
                        .font(.gilroy(.bold, size: 18))
                        .foregroundStyle(.white)
                    Text("Unlock the full experience")
                        .font(.gilroy(.medium, size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            HStack(spacing: 10) {
                benefitChip(icon: "eye.slash.fill", text: "Privacy")
                //benefitChip(icon: "photo.on.rectangle.angled", text: "Portfolio")
                //benefitChip(icon: "paintbrush.fill", text: "Themes")
                benefitChip(icon: "wand.and.stars", text: "Customisations")
                benefitChip(icon: "chart.line.uptrend.xyaxis", text: "Reach")
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)

            HStack {
                Text("Upgrade Now")
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.28, green: 0.27, blue: 0.72),
                                Color(red: 0.48, green: 0.46, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.35, green: 0.34, blue: 0.85).opacity(0.35), radius: 18, y: 10)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.12, blue: 0.18),
                            Color(red: 0.05, green: 0.06, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func benefitChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accentColor)
            Text(text)
                .font(.gilroy(.medium, size: 11))
                .foregroundStyle(.white.opacity(0.7))
                
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.white.opacity(0.06))
        )
        .overlay(
            Capsule()
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}
