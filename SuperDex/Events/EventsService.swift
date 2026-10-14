//
//  EventsService.swift
//  SuperDex
//
//  Reads events from the `events` table in Supabase. The scraping of
//  Luma, Eventbrite, Ticketmaster, SeatGeek and Meetup now happens
//  server-side: the `scrape-events` Edge Function (see
//  supabase/functions/scrape-events/index.ts + events.sql) runs every
//  6 hours and upserts into the table — scrape once, serve every
//  user. The app just issues one fast query; if that fails or the
//  table is empty, curated sample events keep the screen working.
//

import Foundation
import Supabase

struct EventsService {
    /// Row shape of public.events. category/source columns store the
    /// rawValue strings of EventCategory/EventSource.
    private struct EventRow: Codable {
        let id: UUID
        let registration_url: String
        let title: String
        let description: String?
        let category: String
        let city: String
        let venue: String?
        let start_date: Date?
        let image_url: String?
        let price_text: String?
        let source: String

        func toAppEvent() -> AppEvent? {
            guard let url = URL(string: registration_url),
                  let source = EventSource(rawValue: source) else { return nil }
            return AppEvent(
                id: id.uuidString,
                title: title,
                descriptionText: description?.isEmpty == true ? nil : description,
                category: EventCategory(rawValue: category) ?? .other,
                city: city,
                venue: venue,
                startDate: start_date,
                imageURL: image_url.flatMap(URL.init(string:)),
                priceText: price_text,
                source: source,
                registrationURL: url
            )
        }
    }

    /// Fetches upcoming events (plus undated ones), sorted by date.
    /// Paged because PostgREST caps responses at 1000 rows — a single
    /// request would silently drop the furthest-future events.
    /// Returns [] on any failure — the view model falls back to
    /// SampleEvents in that case.
    func fetchAllEvents() async -> [AppEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let formatter = ISO8601DateFormatter()
        let cutoffString = formatter.string(from: cutoff)

        let pageSize = 1000
        var events: [AppEvent] = []
        var offset = 0

        do {
            while true {
                let rows: [EventRow] = try await SupabaseManager.client
                    .from("events")
                    .select()
                    .or("start_date.gte.\(cutoffString),start_date.is.null")
                    .order("start_date", ascending: true)
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                events.append(contentsOf: rows.compactMap { $0.toAppEvent() })
                if rows.count < pageSize { break }
                offset += pageSize
            }
            return events
        } catch {
            return []
        }
    }
}

// MARK: - Detail-page description fetch

enum Scraper {
    /// Desktop Safari UA — event pages serve their full SEO markup
    /// (including JSON-LD) to regular browsers.
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    static func fetchHTML(_ url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return html
    }

    /// Pulls every <script type="application/ld+json"> block out of the
    /// page and returns all schema.org objects whose @type is an Event
    /// (Event, MusicEvent, SportsEvent, BusinessEvent, ...), however
    /// deeply they're nested (@graph, ItemList → item, arrays, ...).
    static func schemaEvents(inHTML html: String) -> [[String: Any]] {
        let pattern = "<script[^>]*type=[\"']application/ld\\+json[\"'][^>]*>(.*?)</script>"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }

        let range = NSRange(html.startIndex..., in: html)
        var events: [[String: Any]] = []

        for match in regex.matches(in: html, range: range) {
            guard let blockRange = Range(match.range(at: 1), in: html) else { continue }
            let block = String(html[blockRange])
            guard let data = block.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            collectEvents(in: json, into: &events)
        }
        return events
    }

    private static func collectEvents(in object: Any, into events: inout [[String: Any]]) {
        if let array = object as? [Any] {
            for element in array { collectEvents(in: element, into: &events) }
            return
        }
        guard let dict = object as? [String: Any] else { return }

        let types: [String]
        if let type = dict["@type"] as? String { types = [type] }
        else if let typeList = dict["@type"] as? [String] { types = typeList }
        else { types = [] }

        if types.contains(where: { $0.hasSuffix("Event") || $0 == "Event" }) {
            events.append(dict)
        }

        // Recurse into containers like @graph, itemListElement, item.
        for value in dict.values {
            collectEvents(in: value, into: &events)
        }
    }

    /// Fetches the full description from an event's own page — the
    /// scraped listing data omits it, but event pages include it.
    /// Used lazily by the detail view.
    static func fetchEventDescription(from url: URL) async -> String? {
        guard let html = try? await fetchHTML(url) else { return nil }
        for dict in schemaEvents(inHTML: html) {
            if let desc = dict["description"] as? String,
               !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return decodeHTMLEntities(desc)
            }
        }
        return nil
    }

    /// Sites label the same city differently ("Bengaluru" vs
    /// "Bangalore", ...). Kept client-side to normalize user-entered
    /// cities (e.g. the Home screen's saved city) against the
    /// canonical names the server stores.
    static func normalizeCity(_ raw: String) -> String {
        let city = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let aliases: [String: String] = [
            "bangalore": "Bengaluru",
            "kings county": "Brooklyn",
            "new york city": "New York",
            "nyc": "New York",
            "manhattan": "New York",
            "greater london": "London",
            "sf": "San Francisco"
        ]
        return aliases[city.lowercased()] ?? city
    }

    static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&#39;": "'", "&#x27;": "'", "&apos;": "'", "&nbsp;": " "
        ]
        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }
}

// MARK: - Sample events (fallback when the events table is unreachable/empty)

enum SampleEvents {
    static func make() -> [AppEvent] {
        let calendar = Calendar.current
        func days(_ n: Int, hour: Int = 18) -> Date {
            let day = calendar.date(byAdding: .day, value: n, to: Date()) ?? Date()
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        }
        func url(_ string: String) -> URL { URL(string: string)! }

        return [
            AppEvent(
                id: "sample-1",
                title: "AI Builders Breakfast",
                descriptionText: "Early morning coffee, demos, and conversations with founders and engineers shipping AI products.",
                category: .tech, city: "San Francisco", venue: "South Park Commons",
                startDate: days(2, hour: 9), imageURL: nil, priceText: "Free",
                source: .luma, registrationURL: url("https://lu.ma/discover")
            ),
            AppEvent(
                id: "sample-2",
                title: "Indie Rock Night: The Wavelengths",
                descriptionText: "Live indie rock with two supporting acts. Doors open at 7 PM.",
                category: .music, city: "New York", venue: "Brooklyn Steel",
                startDate: days(3, hour: 19), imageURL: nil, priceText: "From $45",
                source: .ticketmaster, registrationURL: url("https://www.ticketmaster.com/discover/concerts")
            ),
            AppEvent(
                id: "sample-3",
                title: "Startup Pitch & Networking Mixer",
                descriptionText: "Ten startups pitch live, followed by open networking with investors and operators.",
                category: .networking, city: "Bengaluru", venue: "WeWork Galaxy",
                startDate: days(4), imageURL: nil, priceText: "Free",
                source: .eventbrite, registrationURL: url("https://www.eventbrite.com/d/india--bengaluru/events/")
            ),
            AppEvent(
                id: "sample-4",
                title: "Knicks vs. Celtics",
                descriptionText: "Regular season matchup at Madison Square Garden.",
                category: .sports, city: "New York", venue: "Madison Square Garden",
                startDate: days(6, hour: 19), imageURL: nil, priceText: "From $80",
                source: .seatgeek, registrationURL: url("https://seatgeek.com/cities/new-york")
            ),
            AppEvent(
                id: "sample-5",
                title: "Design Systems Conf 2026",
                descriptionText: "A one-day conference on building and scaling design systems, with workshops in the afternoon.",
                category: .business, city: "London", venue: "The Barbican Centre",
                startDate: days(9, hour: 10), imageURL: nil, priceText: "From £120",
                source: .eventbrite, registrationURL: url("https://www.eventbrite.com/d/united-kingdom--london/events/")
            ),
            AppEvent(
                id: "sample-6",
                title: "Founders & Coffee: Weekly Meetup",
                descriptionText: "Casual weekly meetup for founders and builders. No agenda, just good conversations.",
                category: .networking, city: "San Francisco", venue: "Sightglass Coffee",
                startDate: days(7, hour: 8), imageURL: nil, priceText: "Free",
                source: .luma, registrationURL: url("https://lu.ma/discover")
            ),
            AppEvent(
                id: "sample-7",
                title: "Symphony Under the Stars",
                descriptionText: "Open-air orchestral performance featuring works by Holst and Dvořák.",
                category: .arts, city: "Austin", venue: "Zilker Park",
                startDate: days(11, hour: 20), imageURL: nil, priceText: "From $25",
                source: .ticketmaster, registrationURL: url("https://www.ticketmaster.com/discover/arts-theater")
            ),
            AppEvent(
                id: "sample-8",
                title: "Street Food Festival",
                descriptionText: "50+ food trucks, live music, and craft drinks across two days.",
                category: .food, city: "Berlin", venue: "RAW-Gelände",
                startDate: days(13, hour: 12), imageURL: nil, priceText: "Free entry",
                source: .eventbrite, registrationURL: url("https://www.eventbrite.com/d/germany--berlin/events/")
            ),
            AppEvent(
                id: "sample-9",
                title: "LLM Hack Night",
                descriptionText: "Hands-on hack night: build something with frontier models, demo at the end, pizza included.",
                category: .tech, city: "Bengaluru", venue: "Hasura Office, Indiranagar",
                startDate: days(8, hour: 18), imageURL: nil, priceText: "Free",
                source: .luma, registrationURL: url("https://lu.ma/discover")
            ),
            AppEvent(
                id: "sample-10",
                title: "Stand-up Comedy: Late Night Lineup",
                descriptionText: "Five comedians, one night. 18+ only.",
                category: .arts, city: "London", venue: "Soho Theatre",
                startDate: days(5, hour: 21), imageURL: nil, priceText: "From £18",
                source: .ticketmaster, registrationURL: url("https://www.ticketmaster.co.uk/discover/comedy")
            ),
            AppEvent(
                id: "sample-11",
                title: "Warriors vs. Lakers",
                descriptionText: "Western conference rivalry game at Chase Center.",
                category: .sports, city: "San Francisco", venue: "Chase Center",
                startDate: days(15, hour: 19), imageURL: nil, priceText: "From $95",
                source: .seatgeek, registrationURL: url("https://seatgeek.com/cities/san-francisco")
            ),
            AppEvent(
                id: "sample-12",
                title: "Product-Led Growth Summit",
                descriptionText: "Talks and panels from growth leaders at top SaaS companies.",
                category: .business, city: "Austin", venue: "Austin Convention Center",
                startDate: days(18, hour: 9), imageURL: nil, priceText: "From $150",
                source: .eventbrite, registrationURL: url("https://www.eventbrite.com/d/tx--austin/events/")
            )
        ]
    }
}
