//
//  DiscoverService.swift
//  SuperDex
//
//  Fetches premium user profiles for the Discover tab.
//  Uses the get_discover_profiles RPC which masks fields server-side.
//

import Foundation
import Supabase

struct DiscoverService {
    private let client = SupabaseManager.client

    func fetchPremiumProfiles(excluding userId: UUID) async throws -> [DiscoverProfile] {
        let rows: [DiscoverRow] = try await client
            .rpc("get_discover_profiles", params: ["requesting_user_id": userId.uuidString])
            .execute()
            .value

        return rows.map { $0.toDiscoverProfile() }
    }

    /// Fire-and-forget: record that `viewerId` opened `viewedUserId`'s card in Discover.
    func recordView(viewerId: UUID, viewedUserId: UUID) async {
        struct Params: Encodable {
            let p_viewer_id: String
            let p_viewed_user_id: String
        }
        do {
            try await client
                .rpc("record_discover_view", params: Params(
                    p_viewer_id: viewerId.uuidString,
                    p_viewed_user_id: viewedUserId.uuidString
                ))
                .execute()
        } catch {
            // Non-critical analytics write; ignore failures.
        }
    }

    /// Returns the people who viewed `userId`'s card. Empty unless `userId` is premium
    /// (enforced server-side by the get_my_profile_viewers RPC).
    func fetchMyViewers(userId: UUID) async throws -> [ProfileViewer] {
        let rows: [ViewerRow] = try await client
            .rpc("get_my_profile_viewers", params: ["p_user_id": userId.uuidString])
            .execute()
            .value

        return rows.map { $0.toProfileViewer() }
    }
}

private struct ViewerRow: Codable {
    let viewer_id: UUID
    let first_name: String
    let last_name: String
    let avatar: String
    let job_role: String
    let company_name: String
    let viewed_at: Date

    func toProfileViewer() -> ProfileViewer {
        ProfileViewer(
            id: viewer_id,
            firstName: first_name,
            lastName: last_name,
            avatar: avatar,
            jobRole: job_role,
            companyName: company_name,
            viewedAt: viewed_at
        )
    }
}

struct DiscoverProfile: Identifiable, Hashable {
    let id: UUID
    let card: ProfileCard
}

private struct DiscoverRow: Codable {
    let user_id: UUID
    let first_name: String
    let last_name: String
    let username: String
    let company_name: String
    let job_role: String
    let bio: String
    let phone: String
    let email: String
    let links: [String: String]
    let custom_link_title: String
    let pinned_links: [String]
    let theme_index: Int
    let avatar: String
    let is_premium_user: Bool
    let portfolio_images: [PortfolioImage]
    let qr_code_data: String
    let categories: [String]

    func toDiscoverProfile() -> DiscoverProfile {
        let theme = CardTheme.themes[theme_index % CardTheme.themes.count]
        var card = ProfileCard(
            contactUserId: user_id,
            firstName: first_name,
            lastName: last_name,
            username: username,
            companyName: company_name,
            jobRole: job_role,
            bio: bio,
            phone: phone,
            email: email,
            links: links,
            customLinkTitle: custom_link_title,
            pinnedLinks: pinned_links,
            theme: theme,
            avatar: avatar,
            isPremiumUser: is_premium_user,
            portfolioImages: portfolio_images,
            qrCodeData: qr_code_data,
            categories: categories.compactMap { ProfileCategory(rawValue: $0) }
        )
        card.contactUserId = user_id
        return DiscoverProfile(id: user_id, card: card)
    }
}
