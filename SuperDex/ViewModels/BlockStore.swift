//
//  BlockStore.swift
//  SuperDex
//
//  Local list of blocked users, persisted to UserDefaults. Blocking is applied
//  instantly on-device: blocked users are filtered out of the Discover feed the
//  moment they're blocked (App Store Review Guideline 1.2 — "remove it from the
//  user's feed instantly"). The developer is notified separately via a
//  `content_reports` row written when the user blocks someone.
//

import SwiftUI

struct BlockedUser: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
}

@MainActor
@Observable
final class BlockStore {
    private let defaultsKey = "blockedUsers_v1"
    private let defaults = UserDefaults.standard

    private(set) var blocked: [BlockedUser] = []
    private var blockedIDs: Set<UUID> = []

    init() {
        load()
    }

    func isBlocked(_ id: UUID?) -> Bool {
        guard let id else { return false }
        return blockedIDs.contains(id)
    }

    func block(id: UUID, name: String) {
        guard !blockedIDs.contains(id) else { return }
        blocked.insert(BlockedUser(id: id, name: name), at: 0)
        blockedIDs.insert(id)
        persist()
    }

    func unblock(_ id: UUID) {
        blocked.removeAll { $0.id == id }
        blockedIDs.remove(id)
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([BlockedUser].self, from: data) else { return }
        blocked = decoded
        blockedIDs = Set(decoded.map(\.id))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(blocked) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
