//
//  UserProfileView3.swift
//  HomeScreen
//
//  Created by Gaurang Pant on 12/05/26.
//

import SwiftUI
import Auth

struct UserProfileView: View {
    let profile: ProfileCard
    var isUserProfile: Bool = false
    @Environment(AuthViewModel.self) private var authVM
    @Environment(SubscriptionManager.self) private var subscription
    @State private var showEditProfile = false
    @State private var showProfilePreview = false
    @State private var showProFeatures = false
    @State private var showReportBug = false
    @State private var showRequestFeature = false
    @State private var showDeleteAccountConfirm = false
    @State private var deleteErrorMessage: String?
    @State private var showBlockedUsers = false
    @State private var showPrivacySettings = false
    @Namespace private var cardNamespace

    private var accent: Color {
        profile.theme.gradientColors.first ?? .purple
    }

    private var accentSecondary: Color {
        profile.theme.gradientColors.last ?? .purple
    }

    private var isOnyx: Bool {
        profile.theme.name == "Onyx"
    }

    private var settingsIconAccent: Color {
        isOnyx ? .white : accent
    }

    var body: some View {
        profileTabContent
            .background { backgroundLayer }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet3()
        }
        .navigationDestination(isPresented: $showProfilePreview) {
            ProfileDetailView(profile: profile, isUserProfile: true)
                .navigationTransition(.zoom(sourceID: "settingsCard", in: cardNamespace))
        }
        .navigationDestination(isPresented: $showProFeatures) {
            ProFeaturesView()
        }
        .navigationDestination(isPresented: $showBlockedUsers) {
            BlockedUsersView()
        }
        .navigationDestination(isPresented: $showPrivacySettings) {
            PrivacyVisibilityView()
        }
        .sheet(isPresented: $showReportBug) {
            ReportBugView()
        }
        .sheet(isPresented: $showRequestFeature) {
            RequestFeatureView()
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let ok = await authVM.deleteAccount()
                    if !ok {
                        deleteErrorMessage = authVM.errorMessage ?? "Something went wrong. Please try again."
                    }
                }
            }
        } message: {
            Text("This permanently deletes your profile, contacts, meetings, decks, and subscription data. This action cannot be undone.")
        }
        .alert(
            "Couldn't Delete Account",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        AppBackground(showTopGlow: false)
            .ignoresSafeArea()
    }

    // MARK: - Profile Tab

    private var profileTabContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image((subscription.isPro || profile.isPremiumUser) ? "SuperDexProText" : "SuperDexText")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 14)

                        Text("Profile")
                            .font(.gilroy(.bold, size: 42))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        // Privacy visibility controls are a Pro feature
                        // (paid or whitelisted), matching the gate on
                        // ProfileDetailView's nav bar.
                        if subscription.isPro || profileVM.profile.hasPro {
                            Button {
                                showPrivacySettings = true
                            } label: {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .glassEffect(.clear.interactive(), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .glassEffect(.clear.interactive(), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)
                }
                .padding(.top, 8)

                heroCard

                Button {
                    showProfilePreview = true
                } label: {
                    Text("Tap to Edit or Preview your card")
                        .font(.gilroy(.semiBold, size: 14))
                        .foregroundStyle(Color.white.opacity(0.5))
                }

                if subscription.hasBillingIssue {
                    billingIssueBanner
                }

                subscriptionCard

                appSettingsSection

                deleteAccountButton

                logoutButton

                footerBranding

                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 20)
            .background(alignment: .top) {
                cardGlow
            }
        }
        .reportsTopScroll()
    }

    private var cardGlow: some View {
        ZStack {
            RadialGradient(
                colors: [
                    accent.opacity(0.50),
                    accent.opacity(0.20),
                    accent.opacity(0.05),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.15),
                startRadius: 40,
                endRadius: 700
            )

            RadialGradient(
                colors: [
                    accentSecondary.opacity(0.30),
                    accentSecondary.opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.85, y: 0.12),
                startRadius: 20,
                endRadius: 500
            )
            .blendMode(.plusLighter)
        }
        .frame(height: 900)
        .offset(y: -100)
        .allowsHitTesting(false)
    }

    // MARK: - Hero Card

    @Environment(UserProfileViewModel.self) private var profileVM

    private var heroCard: some View {
        ProfileCardView(
            profile: profile,
            username: isUserProfile ? profileVM.profile.username : nil,
            showsShadow: false,
            allowsFlip: true
        )
        .heroCardFrame(containerPadding: 20)
        .matchedTransitionSource(id: "settingsCard", in: cardNamespace)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showProfilePreview = true
        }
    }

    // MARK: - Billing issue banner

    private var billingIssueBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.18))
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Payment Issue")
                        .font(.gilroy(.bold, size: 15))
                        .foregroundStyle(.white)
                    Text("We couldn't renew your SuperDex Pro subscription. Update your payment method to keep your Pro benefits.")
                        .font(.gilroy(.regular, size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                openURL(SubscriptionManager.updatePaymentURL)
            } label: {
                Text("Update Payment Method")
                    .font(.gilroy(.semiBold, size: 14))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.orange)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Subscription Card

    @ViewBuilder
    private var subscriptionCard: some View {
        if subscription.isPro || profileVM.profile.hasPro {
            manageProCard
        } else {
            UpgradeToProCard()
        }
    }

    private var manageProCard: some View {
        Button { showProFeatures = true } label: {
            HStack(spacing: 14) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("SuperDex Pro")
                        .font(.gilroy(.bold, size: 17))
                        .foregroundStyle(.white)
                    Text("View benefits & manage subscription")
                        .font(.gilroy(.medium, size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(16)
            .background(
                ZStack {
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
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - App Settings

    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Settings")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                settingsRow(icon: "ant.fill", title: "Report a Bug", action: { showReportBug = true })
                settingsRow(icon: "lightbulb.fill", title: "Request a Feature", action: { showRequestFeature = true })
                settingsRow(icon: "hand.raised.fill", title: "Blocked Users", action: { showBlockedUsers = true })
                settingsRow(icon: "envelope.fill", title: "Contact Us", url: URL(string: "mailto:hello@mattr.co.in"))
                settingsRow(icon: "doc.text.fill", title: "Terms & Conditions", url: URL(string: "https://www.superdex.in/terms"))
                settingsRow(icon: "lock.shield.fill", title: "Privacy Policy", url: URL(string: "https://www.superdex.in/privacy"))
            }
        }
    }

    @Environment(\.openURL) private var openURL

    private func settingsRow(icon: String, title: String, url: URL? = nil, action: (() -> Void)? = nil) -> some View {
        Button {
            if let action { action() }
            else if let url { openURL(url) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(settingsIconAccent.opacity(0.15))
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(settingsIconAccent)
                }
                .frame(width: 38, height: 38)

                Text(title)
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.25))
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
        .buttonStyle(.plain)
    }

    // MARK: - Logout

    @State private var isLogoutPressed = false

    private var logoutButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            authVM.signOut()
        } label: {
            Text("Log Out")
                .font(.gilroy(.semiBold, size: 17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delete Account

    private var deleteAccountButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            showDeleteAccountConfirm = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.red.opacity(0.15))
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .frame(width: 38, height: 38)

                Text("Delete My Account")
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.red)

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer Branding

    private var footerBranding: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image("Splash")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Version 1.1.2")
                        .font(.gilroy(.semiBold, size: 13))
                }
                .foregroundStyle(Color.white.opacity(0.45))
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.top, 16)
                .padding(.bottom, 20)

            Text("Building Experiences")
                .font(.gilroy(.bold, size: 28))
                .foregroundStyle(Color.white.opacity(0.15))

            HStack(spacing: 6) {
                Text("that")
                    .font(.gilroy(.bold, size: 28))
                    .foregroundStyle(Color.white.opacity(0.15))

                Image("MattrTextLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                    .opacity(0.85)
                    
            }
            .padding(.top, 2)
        }
        
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
//        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.top, 8)
    }

}

// MARK: - Edit Profile Sheet

private struct EditProfileSheet3: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = UserProfileData()

    var body: some View {
        EditProfileView(profile: $draft, onSave: {
            viewModel.profile = draft
            viewModel.saveProfileImmediately()
            dismiss()
        }, userId: viewModel.currentUserId)
        .onAppear {
            draft = viewModel.profile
        }
    }
}


#Preview {
    NavigationStack {
        UserProfileView(
            profile: ProfileCard(
                firstName: "Ben",
                companyName: "Apple",
                jobRole: "iOS Developer",
                bio: "Building delightful apps one pixel at a time.",
                phone: "+1 (555) 100-2001",
                email: "ben@example.com",
                links: ["instagram": "@ben.dev", "linkedin": "linkedin.com/in/ben", "x": "@ben_dev", "github": "github.com/ben"],
                theme: .glacier
            )
        )
    }
    .environment(AuthViewModel())
}
