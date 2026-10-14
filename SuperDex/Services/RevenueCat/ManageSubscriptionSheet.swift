//
//  ManageSubscriptionSheet.swift
//  SuperDex
//
//  Custom subscription management sheet — replaces RevenueCat's prebuilt
//  Customer Center. Shows current plan, deep-links to Apple's subscription
//  management, restore purchases, and contact support.
//
//      .presentCustomerCenter(isPresented: $show)
//      ManageSubscriptionButton()
//

import SwiftUI
import RevenueCat

extension View {
    /// Present the custom SuperDex subscription management sheet.
    func presentCustomerCenter(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) { ManageSubscriptionSheet() }
    }
}

/// A "Manage Subscription" row you can drop into a settings screen.
struct ManageSubscriptionButton: View {
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "creditcard").font(.gilroy(.semiBold, size: 14))
                Text("Manage Subscription").font(.gilroy(.semiBold, size: 15))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.gilroy(.semiBold, size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .presentCustomerCenter(isPresented: $show)
    }
}

// MARK: - Sheet

struct ManageSubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SubscriptionManager.self) private var subscription

    @State private var showPaywall = false
    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        statusCard.padding(.top, 8)
                        if subscription.isPro { actionsSection } else { upgradeSection }
                        helpSection
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)

                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        toastView(toast).padding(.bottom, 28)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        .paywallSheet(isPresented: $showPaywall)
        .task { await subscription.refresh() }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.085, green: 0.090, blue: 0.115),
                    Color(red: 0.040, green: 0.043, blue: 0.058),
                    Color(red: 0.022, green: 0.024, blue: 0.034)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    (subscription.isPro
                        ? Color(red: 0.45, green: 0.30, blue: 0.95)
                        : Color(red: 0.20, green: 0.24, blue: 0.34)).opacity(0.32),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.0), startRadius: 0, endRadius: 420
            )
            .blendMode(.plusLighter)
        }
    }

    // MARK: Status card

    private var statusCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                if subscription.isPro {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.08))
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.isPro ? "SuperDex Pro" : "Free Plan")
                        .font(.gilroy(.bold, size: 17))
                        .foregroundStyle(.white)
                    Text(statusSubtitle)
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()
                statusPill
            }

            if subscription.isPro, let detail = activeEntitlementDetail {
                Divider().background(Color.white.opacity(0.08))
                VStack(spacing: 8) {
                    detailRow("Plan", value: detail.productLabel)
                    detailRow(detail.expiresLabel, value: detail.expiresValue)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var statusSubtitle: String {
        if subscription.isPro {
            if let d = activeEntitlementDetail, d.willRenew { return "Renews automatically" }
            return "Active"
        }
        return "Upgrade to unlock premium features"
    }

    private var statusPill: some View {
        Text(subscription.isPro ? "ACTIVE" : "INACTIVE")
            .font(.gilroy(.bold, size: 10))
            .tracking(1.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    subscription.isPro
                    ? AnyShapeStyle(Color(red: 0.30, green: 0.75, blue: 0.45))
                    : AnyShapeStyle(Color.white.opacity(0.12))
                )
            )
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.gilroy(.medium, size: 12)).foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(value).font(.gilroy(.semiBold, size: 13)).foregroundStyle(.white.opacity(0.95))
        }
    }

    // MARK: Sections

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("MANAGE")
            ActionRow(icon: "arrow.up.right.square",
                      title: "Manage in App Store",
                      subtitle: "Cancel or change your plan") {
                openURL(RevenueCatConfig.appStoreSubscriptionsURL)
            }
            ActionRow(icon: "arrow.clockwise",
                      title: "Restore Purchases",
                      subtitle: "Recover a subscription on this Apple ID",
                      isLoading: subscription.isProcessing) {
                Task { await restore() }
            }
        }
    }

    private var upgradeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("UNLOCK PRO")
            Button { showPaywall = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.30, blue: 0.95),
                                    Color(red: 0.85, green: 0.30, blue: 0.65)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        Image(systemName: "crown.fill")
                            .font(.gilroy(.semiBold, size: 16))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("See Pro plans")
                            .font(.gilroy(.bold, size: 15))
                            .foregroundStyle(.white)
                        Text("Custom links, pinned cards, portfolio & more")
                            .font(.gilroy(.regular, size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.gilroy(.semiBold, size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.45, green: 0.30, blue: 0.95).opacity(0.6),
                                    Color(red: 0.85, green: 0.30, blue: 0.65).opacity(0.6)
                                ],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)

            ActionRow(icon: "arrow.clockwise",
                      title: "Restore Purchases",
                      subtitle: "Already subscribed? Tap to restore.",
                      isLoading: subscription.isProcessing) {
                Task { await restore() }
            }
        }
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("HELP")
            ActionRow(icon: "envelope",
                      title: "Contact Support",
                      subtitle: "We typically reply within 24h") {
                openURL(RevenueCatConfig.supportEmail)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.gilroy(.semiBold, size: 11))
            .tracking(1.8)
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 4)
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.gilroy(.medium, size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
            .padding(.horizontal, 24)
    }

    private func restore() async {
        let ok = await subscription.restore()
        await showToast(ok ? "Purchases restored." : "No active subscription found.")
    }

    @MainActor
    private func showToast(_ message: String) async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toastMessage = message }
        try? await Task.sleep(nanoseconds: 2_400_000_000)
        withAnimation(.easeInOut(duration: 0.2)) { toastMessage = nil }
    }

    // MARK: Entitlement detail

    private struct EntitlementDetail {
        let productLabel: String
        let expiresLabel: String
        let expiresValue: String
        let willRenew: Bool
    }

    private var activeEntitlementDetail: EntitlementDetail? {
        guard let ent = subscription.customerInfo?.entitlements[RevenueCatConfig.entitlementID],
              ent.isActive else { return nil }

        let product = humanProductLabel(ent.productIdentifier)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if let exp = ent.expirationDate {
            return EntitlementDetail(
                productLabel: product,
                expiresLabel: ent.willRenew ? "Renews on" : "Expires on",
                expiresValue: formatter.string(from: exp),
                willRenew: ent.willRenew
            )
        }
        return EntitlementDetail(productLabel: product, expiresLabel: "Type",
                                 expiresValue: "Lifetime", willRenew: false)
    }

    private func humanProductLabel(_ id: String) -> String {
        switch id {
        case RevenueCatConfig.Product.yearly:  return "SuperDex Pro · Annual"
        case RevenueCatConfig.Product.monthly: return "SuperDex Pro · Monthly"
        default: return id
        }
    }
}

// MARK: - Action row

private struct ActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    Image(systemName: icon)
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.gilroy(.semiBold, size: 14)).foregroundStyle(.white)
                    Text(subtitle)
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                if isLoading {
                    ProgressView().tint(.white.opacity(0.7))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.gilroy(.semiBold, size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
