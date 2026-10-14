//
//  GroupMember.swift
//  SuperDex
//

import Foundation

struct GroupMember: Identifiable, Codable, Hashable {
    var id: UUID
    var userId: UUID?
    var name: String
    var jobRole: String
    var bio: String
    var phone: String
    var email: String
    var instagram: String
    var linkedin: String
    var x: String
    var github: String
    var themeName: String
    var avatar: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, jobRole, bio, phone, email
        case instagram, linkedin, x, github
        case themeName, avatar
    }

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        jobRole: String = "",
        bio: String = "",
        phone: String = "",
        email: String = "",
        instagram: String = "",
        linkedin: String = "",
        x: String = "",
        github: String = "",
        themeName: String = "",
        avatar: String = "memoji1"
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.jobRole = jobRole
        self.bio = bio
        self.phone = phone
        self.email = email
        self.instagram = instagram
        self.linkedin = linkedin
        self.x = x
        self.github = github
        self.themeName = themeName
        self.avatar = avatar
    }

    init(from profile: ProfileCard, userId: UUID? = nil) {
        self.init(
            userId: userId,
            name: profile.name,
            jobRole: profile.jobRole,
            bio: profile.bio,
            phone: profile.phone,
            email: profile.email,
            instagram: profile.instagram,
            linkedin: profile.linkedin,
            x: profile.x,
            github: profile.github,
            themeName: profile.theme.name,
            avatar: profile.avatar
        )
    }

    var asProfileCard: ProfileCard {
        let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
        return ProfileCard(
            contactUserId: userId,
            firstName: parts.first ?? name,
            lastName: parts.count > 1 ? parts[1] : "",
            jobRole: jobRole,
            bio: bio,
            phone: phone,
            email: email,
            links: [
                "instagram": instagram,
                "linkedin": linkedin,
                "x": x,
                "github": github
            ].filter { !$0.value.isEmpty },
            theme: CardTheme.named(themeName) ?? CardTheme.themes[0],
            avatar: avatar
        )
    }
}
