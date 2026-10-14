//
//  DeviceContactsViewModel.swift
//  SuperDex
//
//  Backs the "From your phone" section in Contacts: reads the address book,
//  matches it against SuperDex by phone number, and keeps the two halves
//  (on SuperDex / invite) ready for the list.
//

import SwiftUI
import Auth

@MainActor
@Observable
final class DeviceContactsViewModel {

    typealias AccessState = DeviceContactsService.AccessState

    var accessState: AccessState = DeviceContactsService.currentAccessState()
    var entries: [DeviceContactEntry] = []
    var isLoading = false
    var errorMessage: String?

    /// True once a load has completed, so the section doesn't flash its empty
    /// state before the first read finishes.
    private(set) var hasLoaded = false
    /// Set when the address book was read but the match RPC failed — the list
    /// is still usable, everyone just shows as "invite".
    private(set) var matchFailed = false
    /// The underlying reason, surfaced in DEBUG builds. The usual cause is
    /// find_profiles_by_phone not being deployed yet (see phone_contact_match.sql).
    private(set) var matchErrorMessage: String?

    private let contactsService = DeviceContactsService()
    private let directory = PhoneDirectoryService()
    private var currentUserId: UUID?

    var onSuperDexCount: Int { entries.count { $0.isOnSuperDex } }
    var inviteCount: Int { entries.count { !$0.isOnSuperDex } }

    func configure(userId: UUID?) {
        currentUserId = userId
    }

    func clearOnSignOut() {
        entries = []
        hasLoaded = false
        matchFailed = false
        matchErrorMessage = nil
        errorMessage = nil
        currentUserId = nil
        accessState = DeviceContactsService.currentAccessState()
    }

    // MARK: - Loading

    /// Refreshes the authorization state and loads once. Safe to call from
    /// `.task` every time the section appears.
    func loadIfNeeded() async {
        accessState = DeviceContactsService.currentAccessState()
        guard accessState.canRead, !hasLoaded, !isLoading else { return }
        await load()
    }

    /// Prompts for access if we've never asked, then loads.
    func requestAccessAndLoad() async {
        accessState = await contactsService.requestAccess()
        guard accessState.canRead else { return }
        await load()
    }

    func refresh() async {
        accessState = DeviceContactsService.currentAccessState()
        guard accessState.canRead else { return }
        await load()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        matchFailed = false
        matchErrorMessage = nil
        defer { isLoading = false }

        let devices: [DeviceContact]
        do {
            devices = try await contactsService.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
            hasLoaded = true
            return
        }

        // The address book alone is worth showing — everyone is invitable even
        // if the lookup fails — so land it first and layer matches on top.
        var matches: [String: PhoneMatchedProfile] = [:]
        do {
            matches = try await directory.findProfiles(
                phoneKeys: devices.flatMap(\.matchKeys)
            )
        } catch {
            matchFailed = true
            matchErrorMessage = error.localizedDescription
            #if DEBUG
            print("[DeviceContacts] find_profiles_by_phone failed: \(error)")
            #endif
        }

        entries = devices.map { device in
            let match = device.matchKeys
                .lazy
                .compactMap { matches[$0] }
                // Your own number is in plenty of address books, including
                // your own; a card for yourself in this list is just noise.
                .first { $0.userId != currentUserId }
            return DeviceContactEntry(device: device, match: match)
        }
        .sorted { lhs, rhs in
            // People already on SuperDex first — that's the half of the list
            // with something to act on — then alphabetically within each half.
            if lhs.isOnSuperDex != rhs.isOnSuperDex { return lhs.isOnSuperDex }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        hasLoaded = true
    }
}
