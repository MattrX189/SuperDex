//
//  ContactsViewModel.swift
//  SuperDex
//

import SwiftUI
import Supabase
import Auth

@MainActor
@Observable
final class ContactsViewModel {
    var contacts: [Contact] = []
    var isLoading = false
    var errorMessage: String?

    /// "Auto-share my card when I add someone" (My Card / QR sheet). Off means
    /// ask each time. Per account, on this device.
    private(set) var autoShareCard = false
    /// Whether the one-time tip about auto-share has been shown.
    private(set) var hasSeenShareTip = false

    private let service = ContactService()
    private(set) var currentUserId: UUID?

    func load(for user: User) async {
        if currentUserId == user.id { return }

        currentUserId = user.id
        let defaults = UserDefaults.standard
        // Cached value first, then the account's real setting from the server.
        autoShareCard = defaults.bool(forKey: Self.autoShareKey(user.id))
        hasSeenShareTip = defaults.bool(forKey: Self.shareTipKey(user.id))
        Task { await syncAutoShareCard(userId: user.id) }
        isLoading = true
        defer { isLoading = false }

        do {
            contacts = try await service.fetchAll(userId: user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard let userId = currentUserId else { return }
        do {
            contacts = try await service.fetchAll(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearOnSignOut() {
        currentUserId = nil
        contacts = []
        autoShareCard = false
        hasSeenShareTip = false
    }

    // MARK: - Card sharing preference

    /// Saved to the profile (follows the account to other devices); the
    /// server also uses it to auto-share however a contact gets added.
    func setAutoShareCard(_ on: Bool) {
        autoShareCard = on
        guard let userId = currentUserId else { return }
        UserDefaults.standard.set(on, forKey: Self.autoShareKey(userId))
        Task {
            do {
                try await service.setAutoShareCard(on, userId: userId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func syncAutoShareCard(userId: UUID) async {
        guard let remote = try? await service.fetchAutoShareCard(userId: userId),
              currentUserId == userId else { return }
        autoShareCard = remote
        UserDefaults.standard.set(remote, forKey: Self.autoShareKey(userId))
    }

    // MARK: - Shared cards (receiver side)

    /// Add someone who shared their card with you (server-checked).
    @discardableResult
    func acceptSharedCard(from sharerId: UUID) async -> Bool {
        do {
            let result = try await service.acceptSharedCard(from: sharerId)
            await refresh()
            return result != "no_share"
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// "Not now" — silent; the sharer is never told.
    func declineSharedCard(from sharerId: UUID) async {
        try? await service.declineSharedCard(from: sharerId)
    }

    func markShareTipSeen() {
        hasSeenShareTip = true
        guard let userId = currentUserId else { return }
        UserDefaults.standard.set(true, forKey: Self.shareTipKey(userId))
    }

    private static func autoShareKey(_ userId: UUID) -> String { "cardShare.auto.\(userId)" }
    private static func shareTipKey(_ userId: UUID) -> String { "cardShare.tipSeen.\(userId)" }

    func deleteContacts(ids: Set<UUID>) async -> Bool {
        do {
            try await service.deleteContacts(ids: ids)
            contacts.removeAll { ids.contains($0.id) }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func contactExists(contactUserId: UUID) -> Bool {
        contacts.contains { $0.contactUserId == contactUserId }
    }

    /// The saved contact behind someone found elsewhere (Discover, phone
    /// matches), so they open on the same page as from Contacts.
    func savedContact(for card: ProfileCard) -> Contact? {
        guard let id = card.contactUserId else { return nil }
        return contacts.first { $0.contactUserId == id }
    }

    enum ShareCardResult { case sent, alreadyConnected, failed }

    /// Offer the signed-in user's card to someone they just saved.
    func shareCard(with receiverId: UUID) async -> ShareCardResult {
        do {
            let status = try await service.shareCard(with: receiverId)
            return status == "already_connected" ? .alreadyConnected : .sent
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    @discardableResult
    func addByReference(contactUserId: UUID) async -> Bool {
        guard let userId = currentUserId else { return false }
        do {
            try await service.addContact(userId: userId, contactUserId: contactUserId)
            contacts = try await service.fetchAll(userId: userId)
            return true
        } catch {
            let message = error.localizedDescription
            if message.contains("contacts_unique_pair") || message.contains("duplicate") {
                errorMessage = "already_exists"
            } else {
                errorMessage = message
            }
            return false
        }
    }
}
