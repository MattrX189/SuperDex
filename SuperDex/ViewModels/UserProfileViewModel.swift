//
//  UserProfileViewModel.swift
//  HomeScreen
//

import SwiftUI
import Supabase
import Auth

@MainActor
@Observable
final class UserProfileViewModel {
    var profile = UserProfileData()
    var isEditing = false
    var isLoading = false
    var errorMessage: String?
    var needsOnboarding = false
    /// An existing account signing back in: show the theme picker and the
    /// card launch again before Home.
    var needsThemeRefresh = false
    /// Set to true on the false→true premium transition so the UI can push the
    /// Privacy & Visibility setup screen. Cleared once the user opens it.
    var needsPrivacySetup = false

    private let service = ProfileService()
    let storageService = PortfolioStorageService()
    private var saveTask: Task<Void, Never>?
    private(set) var currentUserId: UUID?

    func load(for user: User, isFreshSignIn: Bool = false) async {
        if currentUserId == user.id { return }

        currentUserId = user.id
        isLoading = true
        defer { isLoading = false }

        do {
            if let remote = try await service.fetch(userId: user.id) {
                profile = remote
                needsOnboarding = remote.username.isEmpty
                needsThemeRefresh = !needsOnboarding && isFreshSignIn
                #if DEBUG
                if needsOnboarding {
                    print("[Onboarding] Showing setup: profile exists for \(user.id) (\(user.email ?? "no email")) but has no username — onboarding was never saved")
                }
                #endif
                // Whitelisted members get Pro privacy controls without going
                // through the upgrade flow that sets them up, so they'd show
                // nothing on Discover. Until they choose otherwise, show all.
                if remote.whitelisted,
                   remote.visibility.discoverVisible.isEmpty,
                   remote.visibility.qrVisible.isEmpty {
                    profile.visibility.discoverVisible = ProfileVisibility.everythingVisible.discoverVisible
                    profile.visibility.qrVisible = ProfileVisibility.everythingVisible.qrVisible
                    try await service.upsert(profile, userId: user.id)
                }
                if !remote.username.isEmpty && remote.qrCodeData.isEmpty {
                    generateQR()
                }
            } else {
                var seeded = UserProfileData()
                // Apple's "Hide My Email" relay address isn't something to
                // show on a business card.
                if let email = user.email, !email.lowercased().hasSuffix("@privaterelay.appleid.com") {
                    seeded.email = email
                }
                profile = seeded
                needsOnboarding = true
                #if DEBUG
                print("[Onboarding] Showing setup: no profile for \(user.id) (\(user.email ?? "no email")) — this sign-in created a new account")
                #endif
                try await service.upsert(seeded, userId: user.id)
            }
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("[Onboarding] Couldn't load profile for \(user.id): \(error)")
            #endif
        }
    }

    func clearOnSignOut() {
        saveTask?.cancel()
        saveTask = nil
        currentUserId = nil
        profile = UserProfileData()
        needsOnboarding = false
        needsThemeRefresh = false
    }

    /// Set by the onboarding card launch so Home can pop the My Card tile
    /// where the card just landed. Home clears it.
    var celebrateMyCard = false

    func completeOnboarding() {
        needsOnboarding = false
        needsThemeRefresh = false
        generateQR()
        // Save straight away (not debounced): until this lands, the account
        // has no username on the server and the next sign-in would show
        // onboarding again.
        guard let userId = currentUserId else { return }
        saveTask?.cancel()
        let snapshot = profile
        saveTask = Task { [service] in
            do {
                try await service.upsert(snapshot, userId: userId)
                #if DEBUG
                print("[Onboarding] Saved profile for \(userId) with username '\(snapshot.username)'")
                #endif
            } catch {
                self.errorMessage = error.localizedDescription
                #if DEBUG
                print("[Onboarding] FAILED to save profile for \(userId): \(error)")
                #endif
            }
        }
    }

    func saveProfile() {
        guard !isLoading else { return }
        guard let userId = currentUserId else { return }

        saveTask?.cancel()
        let snapshot = profile
        saveTask = Task { [service] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            do {
                try await service.upsert(snapshot, userId: userId)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Reflect a RevenueCat entitlement change into the local profile + Supabase.
    /// Idempotent — no-ops when the flag already matches.
    func applyPremiumStatus(_ isPremium: Bool) async {
        guard let userId = currentUserId else { return }
        guard profile.isPremiumUser != isPremium else { return }
        let wasPremium = profile.isPremiumUser
        profile.isPremiumUser = isPremium
        do {
            try await service.updatePremiumStatus(userId: userId, isPremium: isPremium)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProfileImmediately() {
        guard let userId = currentUserId else { return }
        saveTask?.cancel()
        let snapshot = profile
        saveTask = Task { [service] in
            do {
                try await service.upsert(snapshot, userId: userId)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func generateQR() {
        guard !profile.username.isEmpty else { return }
        guard let image = QRCodeViewModel().generateQRCode(username: profile.username),
              let pngData = image.pngData() else { return }
        profile.qrCodeData = pngData.base64EncodedString()
    }
}
