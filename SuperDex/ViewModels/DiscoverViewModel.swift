//
//  DiscoverViewModel.swift
//  SuperDex
//

import SwiftUI
import Supabase
import Auth

@MainActor
@Observable
final class DiscoverViewModel {
    var profiles: [DiscoverProfile] = []
    var isLoading = false
    var errorMessage: String?

    var viewers: [ProfileViewer] = []
    var isLoadingViewers = false
    var viewersError: String?
    var viewerCount: Int { viewers.count }

    private let service = DiscoverService()
    private(set) var currentUserId: UUID?

    func load(for user: User) async {
        if currentUserId == user.id && !profiles.isEmpty { return }
        currentUserId = user.id
        isLoading = true
        defer { isLoading = false }
        do {
            profiles = try await service.fetchPremiumProfiles(excluding: user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard let userId = currentUserId else { return }
        do {
            profiles = try await service.fetchPremiumProfiles(excluding: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Record that the current user opened another member's card. Skips own profile.
    func recordView(of profileId: UUID) {
        guard let viewerId = currentUserId, viewerId != profileId else { return }
        Task {
            await service.recordView(viewerId: viewerId, viewedUserId: profileId)
        }
    }

    /// Load who viewed the current user's card. Server returns empty for non-premium users.
    func loadViewers() async {
        guard let userId = currentUserId else { return }
        isLoadingViewers = true
        defer { isLoadingViewers = false }
        do {
            viewers = try await service.fetchMyViewers(userId: userId)
            viewersError = nil
        } catch {
            viewersError = error.localizedDescription
        }
    }

    func clearOnSignOut() {
        currentUserId = nil
        profiles = []
        viewers = []
    }
}
