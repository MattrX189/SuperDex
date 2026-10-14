//
//  GroupService.swift
//  SuperDex
//

import Foundation
import Supabase

struct GroupService {
    private let client = SupabaseManager.client
    private let table = "groups"

    func fetchAll(userId: UUID) async throws -> [CardGroup] {
        let rows: [GroupRow] = try await client
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute()
            .value

        let allMemberUserIds = Set(rows.flatMap { $0.members.compactMap { $0.userId } })
        let profileMap = try await fetchProfileMap(userIds: Array(allMemberUserIds))

        return rows.map { row in
            var group = row.toCardGroup()
            group.members = group.members.map { hydrate($0, with: profileMap) }
            return group
        }
    }

    func upsert(_ group: CardGroup, userId: UUID) async throws {
        let row = GroupRow(userId: userId, group: group)
        try await client.from(table).upsert(row).execute()
    }

    func delete(id: UUID, userId: UUID) async throws {
        try await client
            .from(table)
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    func refreshedMembers(for members: [GroupMember]) async throws -> [GroupMember] {
        let memberUserIds = members.compactMap { $0.userId }
        guard !memberUserIds.isEmpty else { return members }
        let profileMap = try await fetchProfileMap(userIds: memberUserIds)
        return members.map { hydrate($0, with: profileMap) }
    }

    private func fetchProfileMap(userIds: [UUID]) async throws -> [UUID: MemberProfileRow] {
        guard !userIds.isEmpty else { return [:] }
        let rows: [MemberProfileRow] = try await client
            .rpc("get_contact_profiles", params: ["target_user_ids": userIds.map { $0.uuidString }])
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.user_id, $0) })
    }

    private func hydrate(_ member: GroupMember, with profileMap: [UUID: MemberProfileRow]) -> GroupMember {
        guard let uid = member.userId, let fresh = profileMap[uid] else { return member }
        var updated = member
        let fullName = [fresh.first_name, fresh.last_name]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")
        updated.name = fullName.isEmpty ? member.name : fullName
        updated.jobRole = fresh.job_role
        updated.bio = fresh.bio
        updated.phone = fresh.phone
        updated.email = fresh.email
        updated.instagram = fresh.links[ProfileLink.instagram.rawValue] ?? ""
        updated.linkedin = fresh.links[ProfileLink.linkedin.rawValue] ?? ""
        updated.x = fresh.links[ProfileLink.x.rawValue] ?? ""
        updated.github = fresh.links[ProfileLink.github.rawValue] ?? ""
        updated.themeName = CardTheme.themes[fresh.theme_index % CardTheme.themes.count].name
        updated.avatar = fresh.avatar
        return updated
    }
}

private struct MemberProfileRow: Codable {
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
}

private struct GroupRow: Codable {
    let id: UUID
    let user_id: UUID
    let name: String
    let color_name: String
    let icon: String
    let description_text: String?
    let event_date: Date?
    let location: String?
    let link: String?
    let wallpaper_data: String?
    let members: [GroupMember]

    init(userId: UUID, group: CardGroup) {
        self.id = group.id
        self.user_id = userId
        self.name = group.name
        self.color_name = group.colorName
        self.icon = group.icon
        self.description_text = group.descriptionText
        self.event_date = group.eventDate
        self.location = group.location
        self.link = group.link
        self.wallpaper_data = group.wallpaperData?.base64EncodedString()
        self.members = group.members
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(name, forKey: .name)
        try container.encode(color_name, forKey: .color_name)
        try container.encode(icon, forKey: .icon)
        try container.encode(description_text, forKey: .description_text)
        try container.encode(event_date, forKey: .event_date)
        try container.encode(location, forKey: .location)
        try container.encode(link, forKey: .link)
        try container.encode(wallpaper_data, forKey: .wallpaper_data)
        try container.encode(members, forKey: .members)
    }

    func toCardGroup() -> CardGroup {
        CardGroup(
            id: id,
            name: name,
            colorName: color_name,
            icon: icon,
            descriptionText: description_text,
            eventDate: event_date,
            location: location,
            link: link,
            wallpaperData: wallpaper_data.flatMap { Data(base64Encoded: $0) },
            members: members
        )
    }
}
