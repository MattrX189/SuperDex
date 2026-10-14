//
//  RegisteredEventsStore.swift
//  SuperDex
//
//  Local cache of which events the signed-in user registered for.
//  The event_registrations table on the server is the source of
//  truth; this cache exists so cards and the detail page render the
//  mark instantly. It is keyed per user id — an earlier version used
//  one shared key, which leaked marks across accounts on the same
//  device. Ids are the server-side event row ids, which stay stable
//  across scrape runs (upserts keep the row).
//

import SwiftUI

@Observable
@MainActor
final class RegisteredEventsStore {
    static let shared = RegisteredEventsStore()

    /// The pre-1.1.1 account-agnostic key. Dropped, not migrated:
    /// there is no way to tell which account made those marks.
    private static let legacyStorageKey = "events.registeredIds"

    private(set) var ids: Set<String> = []
    private var activeUserId: UUID?

    private init() {
        UserDefaults.standard.removeObject(forKey: Self.legacyStorageKey)
    }

    private func storageKey(for userId: UUID) -> String {
        "events.registeredIds.\(userId.uuidString)"
    }

    /// Points the store at the signed-in user and loads their cache.
    /// Call before reading; nil (signed out) empties the store.
    func activate(userId: UUID?) {
        guard activeUserId != userId else { return }
        activeUserId = userId
        if let userId {
            ids = Set(UserDefaults.standard.stringArray(forKey: storageKey(for: userId)) ?? [])
        } else {
            ids = []
        }
    }

    func isRegistered(_ eventId: String) -> Bool {
        ids.contains(eventId)
    }

    func markRegistered(_ eventId: String) {
        ids.insert(eventId)
        persist()
    }

    func unmarkRegistered(_ eventId: String) {
        ids.remove(eventId)
        persist()
    }

    /// Replaces the cache with the server's rows for the active user.
    /// Server wins: marks that only exist on this device disappear.
    func syncServerIds(_ serverIds: Set<String>) {
        guard ids != serverIds else { return }
        ids = serverIds
        persist()
    }

    private func persist() {
        guard let userId = activeUserId else { return }
        UserDefaults.standard.set(Array(ids), forKey: storageKey(for: userId))
    }
}
