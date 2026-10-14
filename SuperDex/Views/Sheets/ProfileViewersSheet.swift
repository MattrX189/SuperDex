//
//  ProfileViewersSheet.swift
//  SuperDex
//
//  Premium-only list of people who tapped your card in Discover.
//  Presented from the viewers button in DiscoverView's header.
//

import SwiftUI

struct ProfileViewersSheet: View {
    @Environment(DiscoverViewModel.self) private var viewModel
    @Environment(ContactRequestViewModel.self) private var requestVM
    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(UserProfileViewModel.self) private var profileVM
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    /// Paid (RevenueCat) or dashboard-whitelisted Pro.
    private var isPro: Bool { subscription.isPro || profileVM.profile.hasPro }

    // MARK: - Connect state

    private func connectState(for viewer: ProfileViewer) -> DiscoverConnectState {
        if contactsVM.contactExists(contactUserId: viewer.id) { return .connected }
        switch requestVM.sentStatuses[viewer.id] {
        case .pending:         return .pending
        case .accepted:        return .connected
        case .rejected, .none:  return .connect
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerText
                        .padding(.horizontal, 20)
                        .padding(.top, 28)

                    if !isPro {
                        // The server never sends viewer data to free
                        // members, so show blurred placeholder rows as a
                        // teaser with the upgrade prompt on top.
                        teaserList
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 24)
                            .blur(radius: 10)
                            .allowsHitTesting(false)
                            .overlay { upgradeOverlay }
                    } else if viewModel.isLoadingViewers && viewModel.viewers.isEmpty {
                        loadingState.padding(.top, 80)
                    } else if viewModel.viewers.isEmpty {
                        emptyState.padding(.top, 80)
                    } else {
                        viewerList
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 24)
                    }
                }
            }
            .background(AppBackground())

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
                    .glassEffect(.clear.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, 24)
        }
        .preferredColorScheme(.dark)
        .paywallSheet(isPresented: $showPaywall)
        .task {
            await viewModel.loadViewers()
            await requestVM.refresh()
        }
    }

    // MARK: - Free-tier upgrade overlay

    private var upgradeOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text("Discover who's interested in your work")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white)

            Text("See profile visitors and connect with potential clients, collaborators, and recruiters.")
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPaywall = true
            } label: {
                Text("Upgrade to Pro")
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .background(Color.indigo, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 320)
    }

    // MARK: - Header

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Profile Views")
                .font(.gilroy(.bold, size: 34))
                .foregroundStyle(.white)

            Text(subtitleText)
                .font(.gilroy(.medium, size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var subtitleText: String {
        guard isPro else {
            return "People who tap your card on Discover show up here."
        }
        let count = viewModel.viewerCount
        switch count {
        case 0:  return "People who tap your card on Discover show up here."
        case 1:  return "1 person viewed your card on Discover."
        default: return "\(count) people viewed your card on Discover."
        }
    }

    // MARK: - Free-tier teaser rows

    /// Fake rows rendered under a blur for free members — just believable
    /// enough shapes; never real viewer data.
    private var teaserList: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 14) {
                    Image("memoji\((i % 6) + 1)")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(Color.white.opacity(0.35))
                            .frame(width: 130, height: 12)
                        Capsule().fill(Color.white.opacity(0.18))
                            .frame(width: 90, height: 9)
                    }

                    Spacer(minLength: 8)

                    Capsule().fill(Color.white.opacity(0.12))
                        .frame(width: 82, height: 34)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - List

    private var viewerList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.viewers) { viewer in
                viewerRow(viewer)
            }
        }
    }

    private func viewerRow(_ viewer: ProfileViewer) -> some View {
        HStack(spacing: 14) {
            Image(viewer.avatar)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .background(
                    Circle().fill(Color.white.opacity(0.06))
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(viewer.fullName)
                    .font(.gilroy(.bold, size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !viewer.subtitle.isEmpty {
                    Text(viewer.subtitle)
                        .font(.gilroy(.medium, size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(viewer.relativeTime)
                    .font(.gilroy(.semiBold, size: 12))
                    .foregroundStyle(.white.opacity(0.4))

                DiscoverConnectPill(
                    state: connectState(for: viewer),
                    action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await requestVM.sendRequest(to: viewer.id) }
                    },
                    onWithdraw: {
                        Task { await requestVM.withdrawRequest(to: viewer.id) }
                    }
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white.opacity(0.7))
            Text("Loading your viewers…")
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.35))

            Text("No views yet")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))

            Text("When someone opens your card from Discover, they'll appear here.")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

#Preview {
    ProfileViewersSheet()
        .environment(DiscoverViewModel())
        .environment(ContactRequestViewModel())
        .environment(ContactsViewModel())
        .environment(SubscriptionManager())
        .environment(UserProfileViewModel())
        .preferredColorScheme(.dark)
}
