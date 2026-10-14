//
//  ProfileService.swift
//  SuperDex
//

import Foundation
import Supabase

struct ProfileService {
    private let client = SupabaseManager.client
    private let table = "profiles"

    func fetch(userId: UUID) async throws -> UserProfileData? {
        let rows: [ProfileRow] = try await client
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first?.toData()
    }

    func upsert(_ profile: UserProfileData, userId: UUID) async throws {
        let row = ProfileRow(userId: userId, profile: profile)
        try await client.from(table).upsert(row).execute()
    }

    /// Patch only the `is_premium_user` column. Driven by RevenueCat entitlement changes.
    func updatePremiumStatus(userId: UUID, isPremium: Bool) async throws {
        try await client
            .from(table)
            .update(["is_premium_user": isPremium])
            .eq("user_id", value: userId)
            .execute()
    }

    func fetchByUsername(_ username: String) async throws -> (userId: UUID, profile: UserProfileData)? {
        let rows: [ProfileRow] = try await client
            .from(table)
            .select()
            .eq("username", value: username)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return (row.user_id, row.toData())
    }

    func fetchMaskedByUsername(_ username: String) async throws -> (userId: UUID, profile: UserProfileData)? {
        let rows: [MaskedProfileRow] = try await client
            .rpc("get_profile_by_username", params: ["target_username": username])
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return (row.user_id, row.toData())
    }

    /// Whether another account already uses this phone number. Matches on
    /// digits only, so "+91 90998 16821" and "+919099816821" are the same.
    func isPhoneRegistered(countryCode: String, number: String) async throws -> Bool {
        struct Params: Encodable { let target_phone: String }
        let result: Bool = try await client
            .rpc("is_phone_registered", params: Params(target_phone: "\(countryCode)\(number)"))
            .execute()
            .value
        return result
    }

    func isUsernameTaken(_ username: String, excludingUserId: UUID? = nil) async throws -> Bool {
        struct Params: Encodable {
            let target_username: String
            let excluding_user_id: String?
        }
        let result: Bool = try await client
            .rpc("is_username_taken", params: Params(
                target_username: username,
                excluding_user_id: excludingUserId?.uuidString
            ))
            .execute()
            .value
        return result
    }
}

private struct ProfileRow: Codable {
    let user_id: UUID
    let first_name: String
    let last_name: String
    let username: String?
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
    /// Optional so it's decoded on read but OMITTED on upsert (Swift's
    /// synthesized encoder skips nil optionals). The app must never
    /// write this column — it's set only from the dashboard.
    let whitelisted: Bool?
    let portfolio_images: [PortfolioImage]
    let qr_code_data: String?
    let categories: [String]
    let discover_visible: [String]?
    let qr_visible: [String]?
    let hidden_from_discover: Bool?

    init(userId: UUID, profile: UserProfileData) {
        self.user_id = userId
        self.first_name = profile.firstName
        self.last_name = profile.lastName
        self.username = profile.username.isEmpty ? nil : profile.username
        self.company_name = profile.companyName
        self.job_role = profile.jobRole
        self.bio = profile.bio
        self.phone = profile.phone.isEmpty ? "" : "\(profile.countryCode) \(profile.phone)"
        self.email = profile.email
        self.links = profile.links
        self.custom_link_title = profile.customLinkTitle
        self.pinned_links = profile.pinnedLinks
        self.theme_index = profile.themeIndex
        self.avatar = profile.avatar
        self.is_premium_user = profile.isPremiumUser
        // nil → omitted from the upsert payload, so profile saves can
        // never clobber the dashboard-managed whitelist flag.
        self.whitelisted = nil
        self.portfolio_images = profile.portfolioImages
        self.qr_code_data = profile.qrCodeData.isEmpty ? nil : profile.qrCodeData
        self.categories = profile.categories.map(\.rawValue)
        self.discover_visible = profile.visibility.discoverVisible
        self.qr_visible = profile.visibility.qrVisible
        self.hidden_from_discover = profile.visibility.hiddenFromDiscover
    }

    func toData() -> UserProfileData {
        var data = UserProfileData()
        data.firstName = first_name
        data.lastName = last_name
        data.username = username ?? ""
        data.companyName = company_name
        data.jobRole = job_role
        data.bio = bio
        let parsed = ProfileRow.parsePhone(phone)
        data.countryCode = parsed.code
        data.phone = parsed.number
        data.email = email
        data.links = links
        data.customLinkTitle = custom_link_title
        data.pinnedLinks = pinned_links
        data.themeIndex = theme_index
        data.avatar = avatar
        data.isPremiumUser = is_premium_user
        data.whitelisted = whitelisted ?? false
        data.portfolioImages = portfolio_images
        data.qrCodeData = qr_code_data ?? ""
        data.categories = categories.compactMap { ProfileCategory(rawValue: $0) }
        data.visibility = ProfileVisibility(
            discoverVisible: discover_visible ?? [],
            qrVisible: qr_visible ?? [],
            hiddenFromDiscover: hidden_from_discover ?? false
        )
        return data
    }

    static func parsePhone(_ raw: String) -> (code: String, number: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("+") else {
            return ("+91", trimmed)
        }
        if let spaceIndex = trimmed.firstIndex(of: " ") {
            let code = String(trimmed[..<spaceIndex])
            let number = String(trimmed[trimmed.index(after: spaceIndex)...])
            return (code, number.trimmingCharacters(in: .whitespaces))
        }
        return ("+1", trimmed)
    }
}

private struct MaskedProfileRow: Codable {
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

    func toData() -> UserProfileData {
        var data = UserProfileData()
        data.firstName = first_name
        data.lastName = last_name
        data.username = username
        data.companyName = company_name
        data.jobRole = job_role
        data.bio = bio
        let parsed = ProfileRow.parsePhone(phone)
        data.countryCode = parsed.code
        data.phone = parsed.number
        data.email = email
        data.links = links
        data.customLinkTitle = custom_link_title
        data.pinnedLinks = pinned_links
        data.themeIndex = theme_index
        data.avatar = avatar
        data.isPremiumUser = is_premium_user
        data.portfolioImages = portfolio_images
        data.qrCodeData = qr_code_data
        data.categories = categories.compactMap { ProfileCategory(rawValue: $0) }
        return data
    }
}
