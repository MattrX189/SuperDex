//
//  DiscoverInfoSheet.swift
//  SuperDex
//
//  The ⓘ next to the Discover title: who shows up here (private by
//  default, Pro members can go public and pick what's visible) and the
//  job board. Same layout as ContactsInfoSheet.
//

import SwiftUI

struct DiscoverInfoSheet: View {
    /// Discover's gigs model, so "Post" opens the same composer as GigsScreen.
    let gigsVM: GigsViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(UserProfileViewModel.self) private var profileVM

    @State private var showPaywall = false
    @State private var showProFeatures = false
    @State private var showComposer = false

    private var isPro: Bool { subscription.isPro || profileVM.profile.hasPro }

    private let accent = Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                intro

                featureCard(title: "Who you'll find here", footer: AnyView(exploreProButton), rows: [
                    (
                        "lock.fill",
                        "Private by default",
                        "Every SuperDex profile starts private. Your card is only seen by the people you share it with."
                    ),
                    (
                        "globe",
                        "Pro members go public",
                        "Pro members can make their profile public, so every SuperDex user can find them and connect on Discover."
                    ),
                    (
                        "eye.slash.fill",
                        "You choose what people see",
                        "Pro members also control exactly which details are visible, like their role, company, contact info and links."
                    )
                ])

                featureCard(title: "Hiring or need a hand?", trailing: AnyView(postButton), rows: [
                    (
                        "briefcase.fill",
                        "Post job openings",
                        "Share a job or requirement with the SuperDex community, then see everyone who applied in one place."
                    )
                ])

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.gilroy(.semiBold, size: 16))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white)
                        )
                }
                .buttonStyle(GroupCardPressStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .paywallSheet(isPresented: $showPaywall)
        .sheet(isPresented: $showProFeatures) {
            NavigationStack { ProFeaturesView() }
        }
        .sheet(isPresented: $showComposer) {
            GigComposerSheet(viewModel: gigsVM)
        }
    }

    // MARK: - Actions

    /// Upgrade screen for free members; Pro members see what they have.
    private var exploreProButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isPro { showProFeatures = true } else { showPaywall = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                Text("Explore SuperDex Pro")
                    .font(.gilroy(.semiBold, size: 15))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(.white))
        }
        .buttonStyle(GroupCardPressStyle())
        .padding(.top, 2)
    }

    private var postButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showComposer = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Post")
                    .font(.gilroy(.semiBold, size: 14))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(.white))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Post a job opening")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meet people beyond your circle")
                .font(.gilroy(.bold, size: 30))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Discover is where SuperDex members find each other, and where opportunities get posted.")
                .font(.gilroy(.regular, size: 16))
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func featureCard(
        title: String,
        trailing: AnyView? = nil,
        footer: AnyView? = nil,
        rows: [(icon: String, title: String, detail: String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.gilroy(.bold, size: 20))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                trailing
            }

            ForEach(rows, id: \.title) { row in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle().fill(accent.opacity(0.22))
                        Image(systemName: row.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.gilroy(.semiBold, size: 16))
                            .foregroundStyle(.white)
                        Text(row.detail)
                            .font(.gilroy(.regular, size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }

            footer
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gradientCard(accent: accent, cornerRadius: 24)
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            DiscoverInfoSheet(gigsVM: GigsViewModel())
        }
        .environment(SubscriptionManager())
        .environment(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
