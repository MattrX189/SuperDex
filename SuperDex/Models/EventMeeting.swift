//
//  EventMeeting.swift
//  HomeScreen
//
//  Created by Gaurang Pant on 17/04/26.
//

import Foundation

struct EventMeeting: Identifiable, Hashable {
    let id: UUID
    let eventName: String
    let location: String
    let date: Date
    let notes: String

    init(id: UUID = UUID(), eventName: String, location: String, date: Date, notes: String) {
        self.id = id
        self.eventName = eventName
        self.location = location
        self.date = date
        self.notes = notes
    }
    
    /// Best label for where you met — every field on an interaction is optional,
    /// so fall back from the event name to the location.
    var placeName: String? {
        let event = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !event.isEmpty { return event }
        let place = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return place.isEmpty ? nil : place
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

extension Date {
    /// Short, human "when" for interaction previews: "today", "yesterday",
    /// "3d ago", then a plain date once it's older than a week.
    var interactionAgoText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "today" }
        if calendar.isDateInYesterday(self) { return "yesterday" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: self),
                                           to: calendar.startOfDay(for: .now)).day ?? 0
        if days > 0 && days < 7 { return "\(days)d ago" }
        let sameYear = calendar.isDate(self, equalTo: .now, toGranularity: .year)
        return formatted(sameYear ? .dateTime.day().month(.abbreviated)
                                  : .dateTime.day().month(.abbreviated).year())
    }
}

// Sample meeting data for testing
extension EventMeeting {
    static let sampleMeetings: [EventMeeting] = [
        EventMeeting(
            eventName: "Tech Conference 2026",
            location: "San Francisco, CA",
            date: Date().addingTimeInterval(-30 * 24 * 60 * 60), // 30 days ago
            notes: "Discussed new iOS features and best practices. Very insightful conversation about SwiftUI performance optimization."
        ),
        EventMeeting(
            eventName: "Developer Meetup",
            location: "Local Coffee Shop",
            date: Date().addingTimeInterval(-60 * 24 * 60 * 60), // 60 days ago
            notes: "Shared ideas about app architecture. Talked about their experience with Swift concurrency."
        ),
        EventMeeting(
            eventName: "WWDC Watch Party",
            location: "Apple Park Visitor Center",
            date: Date().addingTimeInterval(-90 * 24 * 60 * 60), // 90 days ago
            notes: "First time meeting! Very enthusiastic about new Apple frameworks. We bonded over our love for SwiftUI."
        )
    ]
}
