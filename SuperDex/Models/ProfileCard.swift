//
//  ProfileCard.swift
//  HomeScreen
//

import Foundation

/// All memoji avatar asset names available in the picker.
/// Add a new entry here when you add a new `memojiN.imageset` to Assets.xcassets.
enum Avatar {
    static let allMemojis: [String] = (1...9).map { "memoji\($0)" }
}

struct ProfileCard: Identifiable, Hashable {
    let id = UUID()
    var contactUserId: UUID?
    let firstName: String
    var lastName: String = ""
    var username: String = ""
    var companyName: String = ""
    let jobRole: String
    let bio: String
    let phone: String
    let email: String
    var links: [String: String] = [:]
    var customLinkTitle: String = ""
    var pinnedLinks: [String] = []
    let theme: CardTheme
    var avatar: String = "memoji1"
    var isPremiumUser: Bool = false
    var portfolioImages: [PortfolioImage] = []
    var qrCodeData: String = ""
    var categories: [ProfileCategory] = []
    var meetings: [EventMeeting] = []
    var visibility: ProfileVisibility = ProfileVisibility()

    var fullName: String {
        [firstName, lastName].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " ")
    }

    var name: String { fullName.isEmpty ? "Your Name" : fullName }

    /// Returns a copy of this card with hidden fields blanked according to
    /// the user's privacy settings for the given surface. Free users (non-premium)
    /// always return self — privacy controls are premium-only.
    func masked(for surface: PrivacySurface) -> ProfileCard {
        guard isPremiumUser else { return self }
        let v = visibility
        let filteredLinks = links.filter { key, _ in
            v.isVisible(.link(key), on: surface)
        }
        return ProfileCard(
            contactUserId: contactUserId,
            firstName: firstName,
            lastName: lastName,
            username: username,
            companyName: v.isVisible(.company, on: surface) ? companyName : "",
            jobRole: v.isVisible(.jobTitle, on: surface) ? jobRole : "",
            bio: v.isVisible(.bio, on: surface) ? bio : "",
            phone: v.isVisible(.phone, on: surface) ? phone : "",
            email: v.isVisible(.email, on: surface) ? email : "",
            links: filteredLinks,
            customLinkTitle: customLinkTitle,
            pinnedLinks: pinnedLinks.filter { filteredLinks[$0] != nil },
            theme: theme,
            avatar: avatar,
            isPremiumUser: isPremiumUser,
            portfolioImages: v.isVisible(.portfolio, on: surface) ? portfolioImages : [],
            qrCodeData: qrCodeData,
            categories: v.isVisible(.category, on: surface) ? categories : [],
            meetings: meetings,
            visibility: visibility
        )
    }

    // Business contact accessors (stored under reserved keys in `links`)
    var businessLogoURL: String { links[UserProfileData.BusinessKey.logoURL] ?? "" }
    var businessPhone: String { links[UserProfileData.BusinessKey.phone] ?? "" }
    var businessCountryCode: String { links[UserProfileData.BusinessKey.countryCode] ?? "" }
    var businessWhatsapp: String { links[UserProfileData.BusinessKey.whatsapp] ?? "" }
    /// Falls back to the business phone's code, like UserProfileData.
    var businessWhatsappCountryCode: String {
        links[UserProfileData.BusinessKey.whatsappCountryCode] ?? businessCountryCode
    }
    var businessEmail: String { links[UserProfileData.BusinessKey.email] ?? "" }

    // Legacy convenience
    var instagram: String { links[ProfileLink.instagram.rawValue] ?? "" }
    var linkedin: String { links[ProfileLink.linkedin.rawValue] ?? "" }
    var x: String { links[ProfileLink.x.rawValue] ?? "" }
    var github: String { links[ProfileLink.github.rawValue] ?? "" }
}

let sampleProfiles: [ProfileCard] = [
    ProfileCard(firstName: "Ben", lastName: "Smith", jobRole: "iOS Developer", bio: "Building delightful apps one pixel at a time.", phone: "+1 (555) 100-2001", email: "ben@example.com", links: ["instagram": "@ben.dev", "linkedin": "linkedin.com/in/ben", "x": "@ben_dev", "github": "github.com/ben"], theme: .aurora, avatar: "memoji1", meetings: EventMeeting.sampleMeetings),
    ProfileCard(firstName: "Sara", lastName: "Lee", jobRole: "UX Designer", bio: "Designing experiences that feel like magic.", phone: "+1 (555) 200-3002", email: "sara@example.com", links: ["instagram": "@sara.ux", "linkedin": "linkedin.com/in/sara", "x": "@sara_ux", "github": "github.com/sara"], theme: .glacier, avatar: "memoji2", meetings: [
        EventMeeting(eventName: "Design Sprint Workshop", location: "New York, NY", date: Date().addingTimeInterval(-45 * 24 * 60 * 60), notes: "Collaborated on user research methods. Learned about their approach to accessibility design.")
    ]),
    ProfileCard(firstName: "Alex", lastName: "Chen", jobRole: "Backend Engineer", bio: "Scaling systems and solving hard problems.", phone: "+1 (555) 300-4003", email: "alex@example.com", links: ["instagram": "@alex.code", "linkedin": "linkedin.com/in/alex", "x": "@alex_code", "github": "github.com/alex"], theme: .coral, avatar: "memoji3"),
    ProfileCard(firstName: "Maya", lastName: "Patel", jobRole: "Product Manager", bio: "Turning ideas into products people love.", phone: "+1 (555) 400-5004", email: "maya@example.com", links: ["instagram": "@maya.pm", "linkedin": "linkedin.com/in/maya", "x": "@maya_pm", "github": "github.com/maya"], theme: .forest, avatar: "memoji4"),
    ProfileCard(firstName: "Jake", lastName: "Wilson", jobRole: "DevOps Engineer", bio: "Automating everything, breaking nothing.", phone: "+1 (555) 500-6005", email: "jake@example.com", links: ["instagram": "@jake.ops", "linkedin": "linkedin.com/in/jake", "x": "@jake_ops", "github": "github.com/jake"], theme: .twilight, avatar: "memoji5"),
    ProfileCard(firstName: "Lily", lastName: "Zhang", jobRole: "Data Scientist", bio: "Finding stories hidden in the numbers.", phone: "+1 (555) 600-7006", email: "lily@example.com", links: ["instagram": "@lily.data", "linkedin": "linkedin.com/in/lily", "x": "@lily_data", "github": "github.com/lily"], theme: .ember, avatar: "memoji6"),
]
