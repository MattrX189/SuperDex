//
//  ContactService.swift
//  SuperDex
//
//  Uses the get_contact_profiles RPC which masks fields server-side
//  based on each user's qr_visible privacy settings.
//

import Foundation
import Supabase

struct ContactService {
    private let client = SupabaseManager.client
    private let table = "contacts"

    func fetchAll(userId: UUID) async throws -> [Contact] {
        let rows: [ContactRefRow] = try await client
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute()
            .value

        let contactUserIds = rows.map { $0.contact_user_id }
        guard !contactUserIds.isEmpty else { return [] }

        let profiles: [ProfileRefRow] = try await client
            .rpc("get_contact_profiles", params: ["target_user_ids": contactUserIds.map { $0.uuidString }])
            .execute()
            .value

        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.user_id, $0) })

        return rows.compactMap { row in
            guard let profile = profileMap[row.contact_user_id] else { return nil }
            var contact = profile.toContact(contactId: row.id, contactUserId: row.contact_user_id)
            contact.connectedAt = row.created_at
            return contact
        }
    }

    func addContact(userId: UUID, contactUserId: UUID) async throws {
        let row = ContactRefRow(id: UUID(), user_id: userId, contact_user_id: contactUserId, created_at: nil)
        try await client.from(table).upsert(row).execute()
    }

    /// After scanning someone, offer them your card back: they get a
    /// `card_shared` notification to add you (see card_share.sql).
    /// Returns "sent" or "already_connected".
    func shareCard(with receiverId: UUID) async throws -> String {
        struct Params: Encodable { let p_receiver_id: String }
        return try await client
            .rpc("share_card", params: Params(p_receiver_id: receiverId.uuidString))
            .execute()
            .value
    }

    /// Receiver adds someone who shared their card — the server checks the
    /// share exists. Returns "added", "already_connected" or "no_share".
    func acceptSharedCard(from sharerId: UUID) async throws -> String {
        struct Params: Encodable { let p_sharer_id: String }
        return try await client
            .rpc("accept_shared_card", params: Params(p_sharer_id: sharerId.uuidString))
            .execute()
            .value
    }

    /// Receiver says "Not now". Recorded server-side; never shown to the sharer.
    func declineSharedCard(from sharerId: UUID) async throws {
        struct Params: Encodable { let p_sharer_id: String }
        try await client
            .rpc("decline_shared_card", params: Params(p_sharer_id: sharerId.uuidString))
            .execute()
    }

    /// profiles.auto_share_card — the account-wide auto-share setting.
    func fetchAutoShareCard(userId: UUID) async throws -> Bool {
        struct Row: Decodable { let auto_share_card: Bool? }
        let rows: [Row] = try await client
            .from("profiles")
            .select("auto_share_card")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first?.auto_share_card ?? false
    }

    func setAutoShareCard(_ on: Bool, userId: UUID) async throws {
        try await client
            .from("profiles")
            .update(["auto_share_card": on])
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteContacts(ids: Set<UUID>) async throws {
        try await client
            .from(table)
            .delete()
            .in("id", values: Array(ids))
            .execute()
    }
}

private struct ContactRefRow: Codable {
    let id: UUID
    let user_id: UUID
    let contact_user_id: UUID
    /// Server-assigned; nil is omitted on encode so the column default applies.
    let created_at: Date?
}

private struct ProfileRefRow: Codable {
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
    let categories: [String]
    let portfolio_images: [PortfolioImage]
    let qr_code_data: String

    func toContact(contactId: UUID, contactUserId: UUID) -> Contact {
        let theme = CardTheme.themes[theme_index % CardTheme.themes.count]
        let card = ProfileCard(
            contactUserId: contactUserId,
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

        return Contact(
            id: contactId,
            contactUserId: contactUserId,
            name: card.fullName,
            username: card.username,
            companyName: card.companyName,
            jobRole: card.jobRole,
            bio: card.bio,
            phone: card.phone,
            email: card.email,
            links: card.links,
            customLinkTitle: card.customLinkTitle,
            pinnedLinks: card.pinnedLinks,
            themeIndex: theme_index,
            avatar: avatar,
            isPremiumUser: is_premium_user,
            categories: card.categories,
            portfolioImages: portfolio_images
        )
    }
}
