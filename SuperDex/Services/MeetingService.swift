//
//  MeetingService.swift
//  SuperDex
//

import Foundation
import Supabase

struct MeetingService {
    private let client = SupabaseManager.client
    private let table = "meetings"

    func fetchAll(userId: UUID, contactUserId: UUID) async throws -> [EventMeeting] {
        let rows: [MeetingRow] = try await client
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .eq("contact_user_id", value: contactUserId)
            .order("date", ascending: false)
            .execute()
            .value
        return rows.map { $0.toMeeting() }
    }

    /// Most recent meeting per contact, for the Home recent-connections cards.
    func fetchLatest(userId: UUID, contactUserIds: [UUID]) async throws -> [UUID: EventMeeting] {
        guard !contactUserIds.isEmpty else { return [:] }
        let rows: [MeetingRow] = try await client
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .in("contact_user_id", values: contactUserIds)
            .order("date", ascending: false)
            .execute()
            .value
        var latest: [UUID: EventMeeting] = [:]
        for row in rows where latest[row.contact_user_id] == nil {
            latest[row.contact_user_id] = row.toMeeting()
        }
        return latest
    }

    /// Every meeting the user has logged, grouped by contact — lets the
    /// Contacts search match on where you met someone and what you discussed.
    func fetchAllByContact(userId: UUID) async throws -> [UUID: [EventMeeting]] {
        let rows: [MeetingRow] = try await client
            .from(table)
            .select()
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute()
            .value
        return Dictionary(grouping: rows, by: \.contact_user_id)
            .mapValues { $0.map { $0.toMeeting() } }
    }

    func insert(_ meeting: EventMeeting, userId: UUID, contactUserId: UUID) async throws {
        let row = MeetingRow(meeting: meeting, userId: userId, contactUserId: contactUserId)
        try await client.from(table).insert(row).execute()
    }

    func update(_ meeting: EventMeeting, userId: UUID, contactUserId: UUID) async throws {
        let row = MeetingRow(meeting: meeting, userId: userId, contactUserId: contactUserId)
        try await client.from(table).upsert(row).execute()
    }

    func delete(id: UUID, userId: UUID) async throws {
        try await client
            .from(table)
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }
}

private struct MeetingRow: Codable {
    let id: UUID
    let user_id: UUID
    let contact_user_id: UUID
    let event_name: String
    let location: String
    let date: Date
    let notes: String

    init(meeting: EventMeeting, userId: UUID, contactUserId: UUID) {
        self.id = meeting.id
        self.user_id = userId
        self.contact_user_id = contactUserId
        self.event_name = meeting.eventName
        self.location = meeting.location
        self.date = meeting.date
        self.notes = meeting.notes
    }

    func toMeeting() -> EventMeeting {
        EventMeeting(
            id: id,
            eventName: event_name,
            location: location,
            date: date,
            notes: notes
        )
    }
}
