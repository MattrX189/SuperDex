//
//  PhoneDirectoryService.swift
//  SuperDex
//
//  Matches device phone numbers against SuperDex accounts via the
//  find_profiles_by_phone RPC (see phone_contact_match.sql).
//
//  Only normalized digit keys go over the wire — never a name, email or
//  anything else from the address book. What comes back is identity only
//  (name, avatar, role, company); phone, email and links stay server-side
//  until the two people actually connect.
//

import Foundation
import Supabase

struct PhoneDirectoryService {
    private let client = SupabaseManager.client

    /// Postgres has to parse the whole array, so send it in slices rather than
    /// one request carrying a 3,000-entry address book.
    private let batchSize = 400

    func findProfiles(phoneKeys: [String]) async throws -> [String: PhoneMatchedProfile] {
        let unique = Array(Set(phoneKeys)).filter { !$0.isEmpty }
        guard !unique.isEmpty else { return [:] }

        var matches: [String: PhoneMatchedProfile] = [:]

        for batch in stride(from: 0, to: unique.count, by: batchSize).map({
            Array(unique[$0..<min($0 + batchSize, unique.count)])
        }) {
            let rows: [PhoneMatchRow] = try await client
                .rpc("find_profiles_by_phone", params: ["phone_keys": batch])
                .execute()
                .value

            for row in rows {
                // First match wins: a number belongs to one account, and if the
                // data ever says otherwise the oldest row is the safer pick.
                if matches[row.match_key] == nil {
                    matches[row.match_key] = row.toMatch()
                }
            }
        }

        return matches
    }
}

private struct PhoneMatchRow: Codable {
    let match_key: String
    let user_id: UUID
    let first_name: String
    let last_name: String
    let username: String
    let company_name: String
    let job_role: String
    let avatar: String
    let theme_index: Int
    let is_premium_user: Bool
    let categories: [String]

    func toMatch() -> PhoneMatchedProfile {
        let card = ProfileCard(
            contactUserId: user_id,
            firstName: first_name,
            lastName: last_name,
            username: username,
            companyName: company_name,
            jobRole: job_role,
            bio: "",
            phone: "",
            email: "",
            theme: CardTheme.themes[theme_index % CardTheme.themes.count],
            avatar: avatar,
            isPremiumUser: is_premium_user,
            categories: categories.compactMap { ProfileCategory(rawValue: $0) }
        )
        return PhoneMatchedProfile(userId: user_id, card: card)
    }
}
