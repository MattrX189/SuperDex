//
//  UserProfileData.swift
//  HomeScreen
//

import Foundation

enum ProfileCategory: String, Codable, CaseIterable, Identifiable {
    case technologySoftware = "Technology & Software"
    case designCreative = "Design & Creative"
    case marketingAdvertising = "Marketing & Advertising"
    case financeBanking = "Finance & Banking"
    case healthcareMedicine = "Healthcare & Medicine"
    case educationAcademia = "Education & Academia"
    case realEstate = "Real Estate"
    case legalLaw = "Legal & Law"
    case contentMedia = "Content & Media"
    case ecommerceRetail = "E-Commerce & Retail"
    case consulting = "Consulting"
    case manufacturingHardware = "Manufacturing & Hardware"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .technologySoftware: return "laptopcomputer"
        case .designCreative: return "paintbrush.fill"
        case .marketingAdvertising: return "megaphone.fill"
        case .financeBanking: return "banknote.fill"
        case .healthcareMedicine: return "heart.fill"
        case .educationAcademia: return "graduationcap.fill"
        case .realEstate: return "building.fill"
        case .legalLaw: return "scalemass.fill"
        case .contentMedia: return "play.rectangle.fill"
        case .ecommerceRetail: return "cart.fill"
        case .consulting: return "chart.line.uptrend.xyaxis"
        case .manufacturingHardware: return "gearshape.2.fill"
        }
    }
}

struct PortfolioImage: Codable, Equatable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var imageURL: String = ""
    var linkURL: String = ""
}

struct UserProfileData: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var username: String = ""
    var companyName: String = ""
    var jobRole: String = ""
    var bio: String = ""
    var countryCode: String = "+91"
    var phone: String = ""
    var email: String = ""
    var themeIndex: Int = 0
    var avatar: String = "memoji1"
    var isPremiumUser: Bool = false
    /// Backend-only "comp" flag: influencers/partners granted full Pro
    /// without paying. Set manually in the dashboard; never written by
    /// the app, and kept separate from `isPremiumUser` (which the
    /// RevenueCat sync overwrites). Use `hasPro` for gating.
    var whitelisted: Bool = false

    // All links stored as [ProfileLink.rawValue: value]
    var links: [String: String] = [:]
    // Custom link heading (premium only)
    var customLinkTitle: String = ""
    // Which links to show on profile card (up to 4, premium only)
    var pinnedLinks: [String] = []
    // Portfolio images with attached links (premium, up to 6)
    var portfolioImages: [PortfolioImage] = []
    var qrCodeData: String = ""
    var categories: [ProfileCategory] = []
    var visibility: ProfileVisibility = ProfileVisibility()

    // Legacy computed properties for backward compatibility
    // Business contact fields (stored in `links` under reserved keys so they
    // persist via the existing JSON column without a schema change).
    enum BusinessKey {
        static let logoURL = "_business_logo_url"
        static let phone = "_business_phone"
        static let countryCode = "_business_country_code"
        static let whatsapp = "_business_whatsapp"
        static let whatsappCountryCode = "_business_whatsapp_country_code"
        static let email = "_business_email"
    }

    // Reserved key for the personal WhatsApp country code (kept separate from the
    // phone country code so the two can differ). Stored in `links`.
    static let whatsappCountryCodeKey = "_whatsapp_country_code"

    /// Country code for the personal WhatsApp number. Independent of `countryCode`.
    /// Falls back to any code embedded in the stored WhatsApp value, then the phone code.
    var whatsappCountryCode: String {
        get {
            if let explicit = links[Self.whatsappCountryCodeKey], !explicit.isEmpty {
                return explicit
            }
            let raw = links[ProfileLink.whatsapp.rawValue] ?? ""
            if raw.hasPrefix("+"), let space = raw.firstIndex(of: " ") {
                return String(raw[..<space])
            }
            return countryCode
        }
        set { links[Self.whatsappCountryCodeKey] = newValue }
    }

    var businessLogoURL: String {
        get { links[BusinessKey.logoURL] ?? "" }
        set { links[BusinessKey.logoURL] = newValue }
    }
    var businessPhone: String {
        get { links[BusinessKey.phone] ?? "" }
        set { links[BusinessKey.phone] = newValue }
    }
    var businessCountryCode: String {
        get { links[BusinessKey.countryCode] ?? countryCode }
        set { links[BusinessKey.countryCode] = newValue }
    }
    var businessWhatsapp: String {
        get { links[BusinessKey.whatsapp] ?? "" }
        set { links[BusinessKey.whatsapp] = newValue }
    }
    /// Country code for the business WhatsApp number. Independent of `businessCountryCode`
    /// (the business phone code); falls back to it when not set.
    var businessWhatsappCountryCode: String {
        get { links[BusinessKey.whatsappCountryCode] ?? businessCountryCode }
        set { links[BusinessKey.whatsappCountryCode] = newValue }
    }
    var businessEmail: String {
        get { links[BusinessKey.email] ?? "" }
        set { links[BusinessKey.email] = newValue }
    }

    var instagram: String {
        get { links[ProfileLink.instagram.rawValue] ?? "" }
        set { links[ProfileLink.instagram.rawValue] = newValue }
    }
    var linkedin: String {
        get { links[ProfileLink.linkedin.rawValue] ?? "" }
        set { links[ProfileLink.linkedin.rawValue] = newValue }
    }
    var x: String {
        get { links[ProfileLink.x.rawValue] ?? "" }
        set { links[ProfileLink.x.rawValue] = newValue }
    }
    var github: String {
        get { links[ProfileLink.github.rawValue] ?? "" }
        set { links[ProfileLink.github.rawValue] = newValue }
    }

    init() {}

    var fullName: String {
        [firstName, lastName].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " ")
    }

    var theme: CardTheme {
        CardTheme.themes[themeIndex % CardTheme.themes.count]
    }

    /// True when the user should get Pro treatment — either a real
    /// subscriber (`isPremiumUser`, synced from RevenueCat) or a
    /// backend-whitelisted influencer/partner. Gate features on this.
    var hasPro: Bool { isPremiumUser || whitelisted }

    var asProfileCard: ProfileCard {
        ProfileCard(
            firstName: firstName,
            lastName: lastName,
            username: username,
            companyName: companyName,
            jobRole: jobRole,
            bio: bio,
            phone: phone.isEmpty ? "" : "\(countryCode) \(phone)",
            email: email,
            links: links,
            customLinkTitle: customLinkTitle,
            pinnedLinks: pinnedLinks,
            theme: theme,
            avatar: avatar,
            // Own card reflects effective Pro so the whitelisted user
            // sees their own badge/logo/features.
            isPremiumUser: hasPro,
            portfolioImages: portfolioImages,
            qrCodeData: qrCodeData,
            categories: categories,
            visibility: visibility
        )
    }

    var resolvedEntries: [ProfileLinkEntry] {
        links.compactMap { key, value in
            guard !value.isEmpty, let link = ProfileLink(rawValue: key) else { return nil }
            return ProfileLinkEntry(
                link: link,
                value: value,
                customLabel: link == .customLink ? customLinkTitle : ""
            )
        }
    }

    var displayedEntries: [ProfileLinkEntry] {
        if isPremiumUser && !pinnedLinks.isEmpty {
            return pinnedLinks.prefix(kMaxDisplayedLinks).compactMap { key in
                guard let link = ProfileLink(rawValue: key),
                      let value = links[key], !value.isEmpty else { return nil }
                return ProfileLinkEntry(
                    link: link,
                    value: value,
                    customLabel: link == .customLink ? customLinkTitle : ""
                )
            }
        }
        let all = resolvedEntries
        return Array(all.prefix(kMaxDisplayedLinks))
    }
}
