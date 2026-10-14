//
//  EventsViewModel.swift
//  SuperDex
//
//  Loads aggregated events and applies the category / city / platform
//  filters.
//

import SwiftUI

@Observable
@MainActor
final class EventsViewModel {
    private enum StorageKey {
        static let category = "events.selectedCategory"
        static let city = "events.selectedCity"
        static let source = "events.selectedSource"
    }

    var events: [AppEvent] = []
    var isLoading = false
    var usingSampleData = false

    var selectedCategory: EventCategory? {
        didSet {
            UserDefaults.standard.set(selectedCategory?.rawValue, forKey: StorageKey.category)
            prefetchThumbnails()
        }
    }
    var selectedCity: String? {
        didSet {
            UserDefaults.standard.set(selectedCity, forKey: StorageKey.city)
            prefetchThumbnails()
        }
    }
    var selectedSource: EventSource? {
        didSet {
            UserDefaults.standard.set(selectedSource?.rawValue, forKey: StorageKey.source)
            prefetchThumbnails()
        }
    }

    private let service = EventsService()
    private var hasLoaded = false

    init() {
        selectedCategory = UserDefaults.standard.string(forKey: StorageKey.category)
            .flatMap(EventCategory.init(rawValue:))
        selectedCity = UserDefaults.standard.string(forKey: StorageKey.city)
        selectedSource = UserDefaults.standard.string(forKey: StorageKey.source)
            .flatMap(EventSource.init(rawValue:))
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let fetched = await service.fetchAllEvents()
        if fetched.isEmpty {
            events = SampleEvents.make()
            usingSampleData = true
        } else {
            events = fetched
            usingSampleData = false
        }
        hasLoaded = true

        // Drop a city filter that no longer matches any event.
        if let city = selectedCity, !cities.contains(city) {
            selectedCity = nil
        }
        // Same for the platform filter (e.g. a site that stopped
        // yielding events since the filter was saved).
        if let source = selectedSource, !availableSources.contains(source) {
            selectedSource = nil
        }

        prefetchThumbnails()
    }

    /// Warms the image cache for the first screenful of the current
    /// filter result, so thumbnails are (mostly) there before the
    /// cards render. Called on load and whenever a filter changes.
    private func prefetchThumbnails() {
        ImageCache.shared.prefetch(
            filteredEvents.prefix(12).compactMap(\.thumbnailURL)
        )
    }

    /// Unique cities across loaded events, for the city filter menu.
    var cities: [String] {
        Array(Set(events.map(\.city))).sorted()
    }

    /// Categories that actually have events, for the filter chips.
    var availableCategories: [EventCategory] {
        EventCategory.allCases.filter { category in
            events.contains { $0.category == category }
        }
    }

    /// Platforms that actually have events, for the platform menu.
    var availableSources: [EventSource] {
        EventSource.allCases.filter { source in
            events.contains { $0.source == source }
        }
    }

    /// How far ahead "Happening this week" looks — roughly a week,
    /// stretched a few days so the weekend after the coming one shows up.
    static let thisWeekWindowDays = 10

    /// Filtered events starting between the start of today and
    /// `thisWeekWindowDays` from now. Undated events are left out since
    /// they can't be placed in the window. Shown on Home and Deck.
    var eventsThisWeek: [AppEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: Self.thisWeekWindowDays + 1, to: start) ?? start
        return filteredEvents.filter { event in
            guard let date = event.startDate else { return false }
            return date >= start && date < end
        }
    }

    var filteredEvents: [AppEvent] {
        events.filter { event in
            (selectedCategory == nil || event.category == selectedCategory)
            && (selectedCity == nil || event.city == selectedCity)
            && (selectedSource == nil || event.source == selectedSource)
        }
    }
}
