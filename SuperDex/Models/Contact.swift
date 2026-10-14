//
//  Contact.swift
//  SuperDex
//

import Foundation

struct Contact: Identifiable, Hashable {
    let id: UUID
    let contactUserId: UUID
    var name: String
    var username: String
    var companyName: String
    var jobRole: String
    var bio: String
    var phone: String
    var email: String
    var links: [String: String]
    var customLinkTitle: String
    var pinnedLinks: [String]
    var themeIndex: Int
    var avatar: String
    var isPremiumUser: Bool
    var categories: [ProfileCategory]
    var portfolioImages: [PortfolioImage]
    /// When this contact was saved (contacts.created_at).
    var connectedAt: Date?

    init(
        id: UUID = UUID(),
        contactUserId: UUID,
        name: String,
        username: String = "",
        companyName: String = "",
        jobRole: String = "",
        bio: String = "",
        phone: String = "",
        email: String = "",
        links: [String: String] = [:],
        customLinkTitle: String = "",
        pinnedLinks: [String] = [],
        themeIndex: Int = 0,
        avatar: String = "memoji1",
        isPremiumUser: Bool = false,
        categories: [ProfileCategory] = [],
        portfolioImages: [PortfolioImage] = [],
        connectedAt: Date? = nil
    ) {
        self.id = id
        self.contactUserId = contactUserId
        self.name = name
        self.username = username
        self.companyName = companyName
        self.jobRole = jobRole
        self.bio = bio
        self.phone = phone
        self.email = email
        self.links = links
        self.customLinkTitle = customLinkTitle
        self.pinnedLinks = pinnedLinks
        self.themeIndex = themeIndex
        self.avatar = avatar
        self.isPremiumUser = isPremiumUser
        self.categories = categories
        self.portfolioImages = portfolioImages
        self.connectedAt = connectedAt
    }

    var instagram: String { links[ProfileLink.instagram.rawValue] ?? "" }
    var linkedin: String { links[ProfileLink.linkedin.rawValue] ?? "" }
    var x: String { links[ProfileLink.x.rawValue] ?? "" }
    var github: String { links[ProfileLink.github.rawValue] ?? "" }

    var theme: CardTheme {
        CardTheme.themes[themeIndex % CardTheme.themes.count]
    }

    var asProfileCard: ProfileCard {
        let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
        return ProfileCard(
            contactUserId: contactUserId,
            firstName: parts.first ?? name,
            lastName: parts.count > 1 ? parts[1] : "",
            username: username,
            companyName: companyName,
            jobRole: jobRole,
            bio: bio,
            phone: phone,
            email: email,
            links: links,
            customLinkTitle: customLinkTitle,
            pinnedLinks: pinnedLinks,
            theme: theme,
            avatar: avatar,
            isPremiumUser: isPremiumUser,
            portfolioImages: portfolioImages,
            categories: categories
        )
    }

    var asGroupMember: GroupMember {
        GroupMember(
            id: id,
            userId: contactUserId,
            name: name,
            jobRole: jobRole,
            bio: bio,
            phone: phone,
            email: email,
            instagram: instagram,
            linkedin: linkedin,
            x: x,
            github: github,
            themeName: theme.name,
            avatar: avatar
        )
    }
}
