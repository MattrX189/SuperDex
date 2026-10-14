//
//  ProfileVisibility.swift
//  SuperDex
//
//  Per-field visibility controls for premium users.
//  Two surfaces: the Discover page and the QR-share flow.
//  Storage: simple [String] arrays of *visible* field keys.
//  Empty array = nothing visible (default for newly-upgraded users).
//

import Foundation

enum ProfileField: Hashable {
    // Non-link fields
    case name
    case username
    case jobTitle
    case company
    case bio
    case phone
    case email
    case category
    case portfolio
    // Each individual link (social or business) keyed by ProfileLink.rawValue
    case link(String)

    var storageKey: String {
        switch self {
        case .name: return "name"
        case .username: return "username"
        case .jobTitle: return "jobTitle"
        case .company: return "company"
        case .bio: return "bio"
        case .phone: return "phone"
        case .email: return "email"
        case .category: return "category"
        case .portfolio: return "portfolio"
        case .link(let raw): return "link.\(raw)"
        }
    }

    var displayName: String {
        switch self {
        case .name: return "Name"
        case .username: return "Username"
        case .jobTitle: return "Job Title"
        case .company: return "Company"
        case .bio: return "Bio"
        case .phone: return "Phone"
        case .email: return "Email"
        case .category: return "Domain"
        case .portfolio: return "Portfolio Images"
        case .link(let raw):
            return ProfileLink(rawValue: raw)?.displayName ?? raw
        }
    }
}

enum PrivacySurface {
    case discover
    case qr

    /// Name and username are always visible — not toggleable on any surface.
    func includes(_ field: ProfileField) -> Bool {
        switch field {
        case .name, .username: return false
        default: return true
        }
    }
}

struct ProfileVisibility: Codable, Equatable, Hashable {
    /// Field storage keys that are visible on the Discover page.
    var discoverVisible: [String] = []
    /// Field storage keys that are shared via QR scan.
    var qrVisible: [String] = []
    /// When true the user is fully excluded from the Discover page.
    var hiddenFromDiscover: Bool = false

    /// Every toggleable field visible on both surfaces — the default for
    /// whitelisted members until they change it (see UserProfileViewModel).
    static var everythingVisible: ProfileVisibility {
        let keys = ProfileField.allGroups.flatMap { $0.fields.map(\.storageKey) }
        return ProfileVisibility(discoverVisible: keys, qrVisible: keys)
    }

    func isVisible(_ field: ProfileField, on surface: PrivacySurface) -> Bool {
        let key = field.storageKey
        switch surface {
        case .discover: return discoverVisible.contains(key)
        case .qr: return qrVisible.contains(key)
        }
    }

    mutating func setVisible(_ field: ProfileField, on surface: PrivacySurface, _ visible: Bool) {
        let key = field.storageKey
        switch surface {
        case .discover:
            if visible {
                if !discoverVisible.contains(key) { discoverVisible.append(key) }
            } else {
                discoverVisible.removeAll { $0 == key }
            }
        case .qr:
            if visible {
                if !qrVisible.contains(key) { qrVisible.append(key) }
            } else {
                qrVisible.removeAll { $0 == key }
            }
        }
    }
}

extension ProfileField {
    /// All toggleable fields, grouped for UI rendering.
    static var allGroups: [(title: String, fields: [ProfileField])] {
        let identity: [ProfileField] = [.jobTitle, .company, .bio]
        let contact: [ProfileField] = [.phone, .email]
        let meta: [ProfileField] = [.category, .portfolio]
        let social: [ProfileField] = ProfileLink.socialOrder.map { .link($0.rawValue) }
        let business: [ProfileField] = ProfileLink.businessOrder.map { .link($0.rawValue) }
        return [
            ("Identity", identity),
            ("Contact", contact),
            ("Profile", meta),
            ("Social Links", social),
            ("Business Links", business)
        ]
    }
}
