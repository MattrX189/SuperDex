//
//  AppEvent.swift
//  SuperDex
//
//  A normalized event pulled from an external listing site
//  (Luma, Ticketmaster, Eventbrite, SeatGeek, ...).
//

import SwiftUI

enum EventSource: String, Codable, CaseIterable, Identifiable, Hashable {
    case luma
    case ticketmaster
    case eventbrite
    case seatgeek
    case meetup

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .luma: return "Luma"
        case .ticketmaster: return "Ticketmaster"
        case .eventbrite: return "Eventbrite"
        case .seatgeek: return "SeatGeek"
        case .meetup: return "Meetup"
        }
    }

    var brandColor: Color {
        switch self {
        case .luma: return Color(red: 0.78, green: 0.40, blue: 0.95)
        case .ticketmaster: return Color(red: 0.00, green: 0.45, blue: 0.95)
        case .eventbrite: return Color(red: 0.94, green: 0.33, blue: 0.22)
        case .seatgeek: return Color(red: 0.20, green: 0.70, blue: 0.55)
        case .meetup: return Color(red: 0.93, green: 0.20, blue: 0.20)
        }
    }

    var icon: String {
        switch self {
        case .luma: return "sparkles"
        case .ticketmaster: return "ticket.fill"
        case .eventbrite: return "calendar.badge.checkmark"
        case .seatgeek: return "chair.lounge.fill"
        case .meetup: return "person.3.fill"
        }
    }

    var websiteURL: URL {
        switch self {
        case .luma: return URL(string: "https://lu.ma/discover")!
        case .ticketmaster: return URL(string: "https://www.ticketmaster.com")!
        case .eventbrite: return URL(string: "https://www.eventbrite.com")!
        case .seatgeek: return URL(string: "https://seatgeek.com")!
        case .meetup: return URL(string: "https://www.meetup.com")!
        }
    }
}

/// Categories mirror Luma's discover taxonomy (Tech, AI, Climate,
/// Fitness, Crypto, Food & Drink, Arts & Culture, Wellness), plus the
/// ones Ticketmaster/Eventbrite events need (Music, Sports, Business,
/// Networking).
enum EventCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case tech
    case ai
    case crypto
    case climate
    case fitness
    case wellness
    case music
    case arts
    case food
    case business
    case networking
    case sports
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tech: return "Tech"
        case .ai: return "AI"
        case .crypto: return "Crypto"
        case .climate: return "Climate"
        case .fitness: return "Fitness"
        case .wellness: return "Wellness"
        case .music: return "Music"
        case .arts: return "Arts & Culture"
        case .food: return "Food & Drink"
        case .business: return "Business"
        case .networking: return "Networking"
        case .sports: return "Sports"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .tech: return "cpu"
        case .ai: return "brain.head.profile"
        case .crypto: return "bitcoinsign.circle.fill"
        case .climate: return "leaf.fill"
        case .fitness: return "figure.run"
        case .wellness: return "figure.mind.and.body"
        case .music: return "music.note"
        case .arts: return "paintpalette.fill"
        case .food: return "fork.knife"
        case .business: return "briefcase.fill"
        case .networking: return "person.2.wave.2.fill"
        case .sports: return "sportscourt.fill"
        case .other: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .tech: return .indigo
        case .ai: return Color(red: 1.00, green: 0.35, blue: 0.60)
        case .crypto: return Color(red: 0.65, green: 0.45, blue: 1.00)
        case .climate: return Color(red: 0.30, green: 0.75, blue: 0.40)
        case .fitness: return Color(red: 1.00, green: 0.45, blue: 0.25)
        case .wellness: return Color(red: 0.35, green: 0.80, blue: 0.75)
        case .music: return .purple
        case .arts: return .pink
        case .food: return .orange
        case .business: return .blue
        case .networking: return .teal
        case .sports: return .green
        case .other: return .gray
        }
    }

    /// Exact mapping from schema.org Event subtypes — these are declared
    /// by the listing site itself, so no guessing involved. Returns nil
    /// for the generic "Event" type or unknown subtypes.
    static func fromSchemaType(_ type: String?) -> EventCategory? {
        switch type {
        case "MusicEvent", "DanceEvent": return .music
        case "SportsEvent": return .sports
        case "TheaterEvent", "ComedyEvent", "VisualArtsEvent",
             "ExhibitionEvent", "LiteraryEvent", "ScreeningEvent": return .arts
        case "FoodEvent": return .food
        case "BusinessEvent", "SaleEvent": return .business
        case "Hackathon": return .tech
        case "SocialEvent": return .networking
        default: return nil
        }
    }

    /// Maps a raw category string (schema.org @type + event title) to an
    /// app category. Short keywords like "ai" are matched against whole
    /// words only — substring matching would tag "blockchain" as AI.
    static func from(raw: String?) -> EventCategory {
        guard let raw = raw?.lowercased() else { return .other }
        let tokens = Set(
            raw.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )
        func word(_ words: String...) -> Bool {
            words.contains { tokens.contains($0) }
        }
        func phrase(_ phrases: String...) -> Bool {
            phrases.contains { raw.contains($0) }
        }

        // Specific topics first, broader buckets last.
        if word("ai", "llm", "llms", "gpt", "genai", "agentic")
            || phrase("artificial intelligence", "machine learning", "deep learning") { return .ai }
        if word("crypto", "web3", "blockchain", "bitcoin", "ethereum", "solana", "nft", "defi") { return .crypto }
        if word("climate", "sustainability", "cleantech", "decarbonization")
            || phrase("net zero", "carbon", "clean energy") { return .climate }
        if word("fitness", "yoga", "pilates", "workout", "marathon", "hike", "cycling", "crossfit")
            || phrase("run club") { return .fitness }
        if word("wellness", "meditation", "mindfulness", "breathwork", "wellbeing") { return .wellness }
        if phrase("music") || word("concert", "dj", "rave", "gig", "band") { return .music }
        if word("art", "arts", "theatre", "theater", "film", "comedy", "museum", "gallery", "culture", "dance") { return .arts }
        if word("food", "drink", "culinary", "tasting", "dinner", "brunch", "wine", "coffee") { return .food }
        if phrase("sport") || word("nba", "nfl", "mlb", "nhl", "soccer", "cricket", "football") { return .sports }
        if word("networking", "mixer", "meetup", "community", "social") { return .networking }
        if word("business", "conference", "summit", "startup", "founders", "pitch", "marketing", "finance") { return .business }
        if word("tech", "software", "coding", "hackathon", "developer", "developers", "data", "cloud", "saas") { return .tech }
        return .other
    }
}

struct AppEvent: Identifiable, Hashable {
    let id: String
    var title: String
    var descriptionText: String?
    var category: EventCategory
    var city: String
    var venue: String?
    var startDate: Date?
    var imageURL: URL?
    var priceText: String?
    var source: EventSource
    var registrationURL: URL
}

extension AppEvent {
    /// Search match on name, venue, city, category and platform. Every
    /// word must appear somewhere, so "ai bengaluru" narrows rather than widens.
    func matches(_ query: String) -> Bool {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = [title, venue ?? "", city, category.displayName, source.displayName]
            .joined(separator: " ")
            .lowercased()
        return words.allSatisfy { haystack.contains($0) }
    }

    /// A small rendition of imageURL for 64pt list thumbnails. The
    /// event sites serve multi-hundred-KB originals; where the CDN
    /// supports resizing, rewrite the URL to a ~200px variant so list
    /// thumbnails cost kilobytes instead of megabytes. Falls back to
    /// the original URL for CDNs without a known resize scheme.
    var thumbnailURL: URL? {
        guard let imageURL else { return nil }
        let host = imageURL.host() ?? ""
        let thumbOptions = "format=auto,fit=cover,width=200,height=200,quality=75"

        // Luma — Cloudflare image resizing (/cdn-cgi/image/<options>/<path>)
        if host.contains("lumacdn.com") || host.hasSuffix("lu.ma") {
            let path = imageURL.path()
            if path.hasPrefix("/cdn-cgi/image/") {
                let parts = path.split(separator: "/", maxSplits: 3, omittingEmptySubsequences: true)
                if parts.count == 4 {
                    return URL(string: "https://\(host)/cdn-cgi/image/\(thumbOptions)/\(parts[3])") ?? imageURL
                }
            }
            return URL(string: "https://\(host)/cdn-cgi/image/\(thumbOptions)\(path)") ?? imageURL
        }

        // Eventbrite is deliberately NOT rewritten: its image URLs are
        // signed (the s= param covers the exact query string), so any
        // change to w/h gets a 403. The scraped URLs are already
        // ~300px / ~30 KB — small enough as-is.

        // Meetup — size-prefixed filenames (highres_x.jpeg → 300_x.jpeg)
        if host.contains("meetupstatic.com") {
            let string = imageURL.absoluteString
            for prefix in ["highres_", "600_"] where string.contains(prefix) {
                return URL(string: string.replacingOccurrences(of: prefix, with: "300_")) ?? imageURL
            }
        }

        return imageURL
    }
}
