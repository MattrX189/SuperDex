//
//  ProfileLink.swift
//  SuperDex
//
//  Catalog of every link type the user can put on their profile.
//  Storage is a `[String: String]` map keyed by `ProfileLink.rawValue`,
//  so the JSON shape stays simple and forward-compatible.
//

import Foundation

enum ProfileLink: String, CaseIterable, Codable, Hashable {
    // MARK: Social
    case instagram
    case linkedin
    case x
    case facebook
    case whatsapp
    case youtube
    case telegram
    case snapchat
    case discord
    case reddit
    case threads

    // MARK: Business
    case customLink
    case calendly
    case appStore
    case behance
    case dribbble
    case github
    case medium
    case linktree
    case figma
    case spotify
    case vimeo
    case pinterest

    enum Category: String, CaseIterable, Hashable {
        case social
        case business

        var title: String {
            switch self {
            case .social: return "Social Media"
            case .business: return "Business"
            }
        }
    }

    var category: Category {
        switch self {
        case .instagram, .linkedin, .x, .facebook,
             .whatsapp, .youtube, .telegram, .snapchat,
             .discord, .reddit, .threads:
            return .social
        case .customLink, .calendly, .appStore, .behance, .dribbble,
             .github, .medium, .linktree, .figma, .spotify, .vimeo,
             .pinterest:
            return .business
        }
    }

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .linkedin: return "LinkedIn"
        case .x: return "X"
        case .facebook: return "Facebook"
        case .whatsapp: return "WhatsApp"
        case .youtube: return "YouTube"
        case .telegram: return "Telegram"
        case .snapchat: return "Snapchat"
        case .discord: return "Discord"
        case .reddit: return "Reddit"
        case .threads: return "Threads"
        case .customLink: return "Custom Link"
        case .calendly: return "Calendly"
        case .appStore: return "App Store"
        case .behance: return "Behance"
        case .dribbble: return "Dribbble"
        case .github: return "GitHub"
        case .medium: return "Medium"
        case .linktree: return "Linktree"
        case .figma: return "Figma"
        case .spotify: return "Spotify"
        case .vimeo: return "Vimeo"
        case .pinterest: return "Pinterest"
        }
    }

    /// SF Symbol used when there isn't a custom-drawn brand glyph in `BrandIcon`.
    var fallbackSymbol: String {
        switch self {
        case .instagram: return "camera.fill"
        case .linkedin: return "person.2.fill"
        case .x: return "at"
        case .facebook: return "f.circle.fill"
        case .whatsapp: return "bubble.left.and.bubble.right.fill"
        case .youtube: return "play.rectangle.fill"
        case .telegram: return "paperplane.fill"
        case .snapchat: return "camera.viewfinder"
        case .discord: return "bubble.left.and.text.bubble.right.fill"
        case .reddit: return "person.crop.circle.fill"
        case .threads: return "at.circle.fill"
        case .customLink: return "link"
        case .calendly: return "calendar"
        case .appStore: return "app.badge.fill"
        case .behance: return "b.circle.fill"
        case .dribbble: return "basketball.fill"
        case .github: return "terminal.fill"
        case .medium: return "m.circle.fill"
        case .linktree: return "tree.fill"
        case .figma: return "paintpalette.fill"
        case .spotify: return "music.note"
        case .vimeo: return "v.circle.fill"
        case .pinterest: return "pin.fill"
        }
    }

    var brandIconName: String? {
        switch self {
        case .instagram: return "instagram"
        case .linkedin: return "linkedin"
        case .x: return "x"
        case .facebook: return "facebook"
        case .github: return "github"
        case .whatsapp: return "whatsapp"
        case .youtube: return "youtube"
        case .telegram: return "telegram"
        case .snapchat: return "snapchat"
        case .behance: return "behance"
        case .dribbble: return "dribbble"
        case .appStore: return "appStore"
        case .medium: return "medium"
        case .linktree: return "linktree"
        case .figma: return "figma"
        case .spotify: return "spotify"
        case .vimeo: return "vimeo"
        case .discord: return "discord"
        case .reddit: return "reddit"
        case .threads: return "threads"
        case .pinterest: return "pinterest"
        default: return nil
        }
    }

    var inputPlaceholder: String {
        switch self {
        case .instagram: return "@username or full URL"
        case .linkedin: return "linkedin.com/in/handle"
        case .x: return "@username"
        case .facebook: return "facebook.com/username"
        case .whatsapp: return "+15551234567"
        case .youtube: return "youtube.com/@channel"
        case .telegram: return "@username"
        case .snapchat: return "@username"
        case .discord: return "discord.gg/invite or username"
        case .reddit: return "u/username"
        case .threads: return "@username"
        case .customLink: return "https://example.com"
        case .calendly: return "calendly.com/handle"
        case .appStore: return "https://apps.apple.com/…"
        case .behance: return "behance.net/handle"
        case .dribbble: return "dribbble.com/handle"
        case .github: return "github.com/handle"
        case .medium: return "medium.com/@handle"
        case .linktree: return "linktr.ee/handle"
        case .figma: return "figma.com/@handle"
        case .spotify: return "open.spotify.com/user/…"
        case .vimeo: return "vimeo.com/handle"
        case .pinterest: return "pinterest.com/handle"
        }
    }

    /// Resolve a stored value into a tappable URL.
    /// If the value already looks like a URL, use it as-is; otherwise wrap
    /// it in the platform's canonical pattern.
    func url(for value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        if trimmed.contains("://") {
            return URL(string: trimmed)
        }

        let handle = trimmed.replacingOccurrences(of: "@", with: "")

        // Many platforms accept either a bare handle or a domain-prefixed
        // value pasted by the user. Detect a domain to avoid double-prefixing.
        func wrap(domain: String, withAt: Bool = false) -> URL? {
            if trimmed.contains(domain) {
                return URL(string: "https://\(trimmed)")
            }
            return URL(string: "https://\(domain)/\(withAt ? "@" : "")\(handle)")
        }

        switch self {
        case .instagram: return wrap(domain: "instagram.com")
        case .linkedin:
            if trimmed.contains("linkedin.com") {
                return URL(string: "https://\(trimmed)")
            }
            return URL(string: "https://linkedin.com/in/\(handle)")
        case .x: return wrap(domain: "x.com")
        case .facebook: return wrap(domain: "facebook.com")
        case .whatsapp:
            let digits = handle.filter { $0.isNumber }
            return URL(string: "https://wa.me/\(digits)")
        case .youtube: return wrap(domain: "youtube.com", withAt: true)
        case .telegram: return wrap(domain: "t.me")
        case .snapchat:
            if trimmed.contains("snapchat.com") {
                return URL(string: "https://\(trimmed)")
            }
            return URL(string: "https://snapchat.com/add/\(handle)")
        case .customLink:
            return URL(string: "https://\(trimmed)")
        case .calendly: return wrap(domain: "calendly.com")
        case .appStore:
            return URL(string: "https://\(trimmed)")
        case .behance: return wrap(domain: "behance.net")
        case .dribbble: return wrap(domain: "dribbble.com")
        case .github: return wrap(domain: "github.com")
        case .medium: return wrap(domain: "medium.com", withAt: true)
        case .linktree: return wrap(domain: "linktr.ee")
        case .figma: return wrap(domain: "figma.com", withAt: true)
        case .spotify:
            if trimmed.contains("spotify.com") {
                return URL(string: "https://\(trimmed)")
            }
            return URL(string: "https://open.spotify.com/user/\(handle)")
        case .vimeo: return wrap(domain: "vimeo.com")
        case .discord:
            if trimmed.contains("discord") {
                return URL(string: "https://\(trimmed)")
            }
            return URL(string: "https://discord.gg/\(handle)")
        case .reddit:
            if trimmed.contains("reddit.com") {
                return URL(string: "https://\(trimmed)")
            }
            return URL(string: "https://reddit.com/u/\(handle)")
        case .threads: return wrap(domain: "threads.net", withAt: true)
        case .pinterest: return wrap(domain: "pinterest.com")
        }
    }

    static let socialOrder: [ProfileLink] = [
        .whatsapp, .instagram, .linkedin, .x, .facebook,
        .youtube, .telegram, .snapchat, .discord, .reddit, .threads
    ]

    static let businessOrder: [ProfileLink] = [
        .customLink, .calendly, .appStore, .behance, .dribbble,
        .github, .medium, .linktree, .figma, .spotify, .vimeo,
        .pinterest
    ]
}

/// A non-empty link entry resolved from a profile, ready to render.
struct ProfileLinkEntry: Hashable {
    let link: ProfileLink
    let value: String
    /// User-supplied heading shown for `.customLink`.
    let customLabel: String

    var url: URL? { link.url(for: value) }

    var label: String {
        if link == .customLink, !customLabel.isEmpty {
            return customLabel
        }
        return link.displayName
    }
}

/// Maximum links the user can pin to their profile card.
let kMaxDisplayedLinks: Int = 4
