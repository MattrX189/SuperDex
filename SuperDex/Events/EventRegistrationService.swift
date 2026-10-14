//
//  EventRegistrationService.swift
//  SuperDex
//
//  Server-side "I'm going" marks for events. RegisteredEventsStore
//  keeps the fast local copy; this service mirrors it to the
//  event_registrations table (see event_registrations.sql) so the
//  event page can show which SuperDex users are attending.
//

import Foundation
import Supabase

/// One person in an event's attendee list. The get_event_attendees
/// RPC masks profiles down to name, avatar, job title, company and
/// bio — the full card stays gated behind an accepted connect
/// request, like everywhere else in the app.
struct EventAttendee: Identifiable, Hashable {
    let id: UUID
    let firstName: String
    let lastName: String
    let avatar: String
    let jobRole: String
    let companyName: String
    let bio: String

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var subtitle: String {
        switch (jobRole.isEmpty, companyName.isEmpty) {
        case (false, false): return "\(jobRole) at \(companyName)"
        case (false, true):  return jobRole
        case (true, false):  return companyName
        case (true, true):   return ""
        }
    }
}

struct EventRegistrationService {
    private let client = SupabaseManager.client

    /// Everyone who marked themselves registered for the event,
    /// earliest first. nil means the fetch failed (offline, table
    /// missing) — distinct from an empty list, so callers don't
    /// treat an outage as "no one is going". Sample events (non-UUID
    /// ids) have no server rows and return [].
    func fetchAttendees(eventId: String) async -> [EventAttendee]? {
        guard let eventUUID = UUID(uuidString: eventId) else { return [] }
        do {
            let rows: [AttendeeRow] = try await client
                .rpc("get_event_attendees", params: ["p_event_id": eventUUID.uuidString])
                .execute()
                .value
            return rows.map { $0.toAttendee() }
        } catch {
            return nil
        }
    }

    /// Fire-and-forget mirror of a local "registered" mark. Failures
    /// (offline, sample event, event row already cleaned up) are
    /// ignored — the local store stays the source of truth for the
    /// user's own marks.
    func register(eventId: String, userId: UUID) async {
        guard let eventUUID = UUID(uuidString: eventId) else { return }
        let row = RegistrationInsert(event_id: eventUUID, user_id: userId)
        _ = try? await client
            .from("event_registrations")
            .upsert(row)
            .execute()
    }

    /// Fire-and-forget mirror of a local unmark.
    func unregister(eventId: String, userId: UUID) async {
        guard let eventUUID = UUID(uuidString: eventId) else { return }
        _ = try? await client
            .from("event_registrations")
            .delete()
            .eq("event_id", value: eventUUID)
            .eq("user_id", value: userId)
            .execute()
    }

    /// Ids of every event this user registered for, used to sync the
    /// local cache. nil means the fetch failed — callers must keep
    /// the cache instead of wiping it.
    func fetchRegisteredEventIds(userId: UUID) async -> Set<String>? {
        do {
            let rows: [RegistrationRow] = try await client
                .from("event_registrations")
                .select("event_id")
                .eq("user_id", value: userId)
                .execute()
                .value
            return Set(rows.map { $0.event_id.uuidString })
        } catch {
            return nil
        }
    }
}

// MARK: - Row models

private struct AttendeeRow: Decodable {
    let user_id: UUID
    let first_name: String
    let last_name: String
    let avatar: String
    let job_role: String
    let company_name: String
    let bio: String
    let registered_at: Date

    func toAttendee() -> EventAttendee {
        EventAttendee(
            id: user_id,
            firstName: first_name,
            lastName: last_name,
            avatar: avatar,
            jobRole: job_role,
            companyName: company_name,
            bio: bio
        )
    }
}

private struct RegistrationInsert: Encodable {
    let event_id: UUID
    let user_id: UUID
}

private struct RegistrationRow: Decodable {
    let event_id: UUID
}
