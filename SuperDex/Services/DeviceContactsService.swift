//
//  DeviceContactsService.swift
//  SuperDex
//
//  Reads the device address book. Nothing here leaves the device: the
//  matching step (PhoneDirectoryService) sends only hashed-down numeric
//  keys, never names, emails or the contacts themselves.
//

import Foundation
import Contacts

struct DeviceContactsService {

    enum AccessState: Equatable {
        case notDetermined
        case denied
        case restricted
        /// Full address book (`.authorized`).
        case granted
        /// iOS 18+ partial access — the user picked specific contacts to share.
        case limited

        var canRead: Bool { self == .granted || self == .limited }
    }

    enum ServiceError: LocalizedError {
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "SuperDex doesn't have access to your contacts."
            }
        }
    }

    static func currentAccessState() -> AccessState {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:    return .granted
        case .limited:       return .limited
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .notDetermined: return .notDetermined
        @unknown default:    return .notDetermined
        }
    }

    /// Shows the system prompt when the status is still undetermined.
    /// Returns the state afterwards, so callers can branch on `.limited`.
    func requestAccess() async -> AccessState {
        let current = Self.currentAccessState()
        guard current == .notDetermined else { return current }

        let store = CNContactStore()
        _ = try? await store.requestAccess(for: .contacts)
        return Self.currentAccessState()
    }

    /// Reads every contact the app is allowed to see. Runs off the main actor —
    /// enumerating a large address book is slow enough to drop frames.
    func fetchAll() async throws -> [DeviceContact] {
        guard Self.currentAccessState().canRead else {
            throw ServiceError.accessDenied
        }

        return try await Task.detached(priority: .userInitiated) {
            let keys: [CNKeyDescriptor] = [
                CNContactIdentifierKey,
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactOrganizationNameKey,
                CNContactJobTitleKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey,
                CNContactThumbnailImageDataKey
            ].map { $0 as CNKeyDescriptor }

            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .givenName
            request.unifyResults = true

            var results: [DeviceContact] = []
            let store = CNContactStore()

            try store.enumerateContacts(with: request) { contact, _ in
                let numbers = contact.phoneNumbers.map { $0.value.stringValue }
                // A contact with no number can't be matched or invited, so it
                // would only ever render as an inert row.
                guard !numbers.isEmpty else { return }

                results.append(
                    DeviceContact(
                        id: contact.identifier,
                        givenName: contact.givenName,
                        familyName: contact.familyName,
                        organizationName: contact.organizationName,
                        jobTitle: contact.jobTitle,
                        phoneNumbers: numbers,
                        emails: contact.emailAddresses.map { $0.value as String },
                        thumbnail: contact.thumbnailImageData
                    )
                )
            }

            return Self.collapsingDuplicates(results)
        }.value
    }

    // MARK: - Duplicate collapsing

    /// Address books accumulate the same person many times over: a number
    /// synced from both iCloud and Google, a contact saved twice, a card
    /// imported from WhatsApp. `unifyResults` only links entries iOS can
    /// confidently match *by name*, so the same number still arrives as
    /// several CNContacts — which is why an address book can show "#Prankster"
    /// three times.
    ///
    /// For this screen a phone number *is* the identity: it's what we match
    /// against SuperDex and what an invite is sent to, so three rows for one
    /// number means three identical cards and three identical invites. Collapse
    /// on the number and keep the fullest copy of the person.
    ///
    /// Internal rather than private so it can be exercised directly.
    static func collapsingDuplicates(_ contacts: [DeviceContact]) -> [DeviceContact] {
        var merged: [DeviceContact] = []
        /// normalized phone key → index into `merged`
        var slotForKey: [String: Int] = [:]

        for contact in contacts {
            let keys = contact.matchKeys

            // No usable digits at all (a "phone number" like "N/A"). Nothing to
            // match on, so leave it alone rather than merging it with anything.
            guard !keys.isEmpty else {
                merged.append(contact)
                continue
            }

            // Sharing any number with someone we've already seen means we've
            // met this person — a contact saved once with mobile+home and once
            // with just home is still one person.
            if let slot = keys.compactMap({ slotForKey[$0] }).first {
                merged[slot] = merge(merged[slot], contact)
                for key in merged[slot].matchKeys where slotForKey[key] == nil {
                    slotForKey[key] = slot
                }
            } else {
                let slot = merged.count
                merged.append(contact)
                for key in keys { slotForKey[key] = slot }
            }
        }

        return merged
    }

    /// Keeps the better-identified of two records and folds in anything the
    /// other one knew — so merging never loses a number, a photo or a company.
    private static func merge(_ a: DeviceContact, _ b: DeviceContact) -> DeviceContact {
        let aWins = score(a) >= score(b)
        var winner = aWins ? a : b
        let loser = aWins ? b : a

        winner.phoneNumbers = unionNumbers(winner.phoneNumbers, loser.phoneNumbers)
        winner.emails = unionCaseInsensitive(winner.emails, loser.emails)
        if winner.thumbnail == nil { winner.thumbnail = loser.thumbnail }
        if winner.givenName.isBlank { winner.givenName = loser.givenName }
        if winner.familyName.isBlank { winner.familyName = loser.familyName }
        if winner.organizationName.isBlank { winner.organizationName = loser.organizationName }
        if winner.jobTitle.isBlank { winner.jobTitle = loser.jobTitle }

        return winner
    }

    /// How well-identified a record is. A real first and last name beats an
    /// entry that's only a number or an org, which is what decides whose name
    /// survives a merge.
    private static func score(_ contact: DeviceContact) -> Int {
        var total = 0
        if !contact.givenName.isBlank { total += 4 }
        if !contact.familyName.isBlank { total += 3 }
        if contact.thumbnail != nil { total += 2 }
        if !contact.organizationName.isBlank { total += 1 }
        if !contact.jobTitle.isBlank { total += 1 }
        if !contact.emails.isEmpty { total += 1 }
        return total
    }

    /// Union by normalized key, keeping each number in the form it was first
    /// stored — "+91 98765 43210" and "09876543210" are one number, shown once.
    private static func unionNumbers(_ lhs: [String], _ rhs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for number in lhs + rhs {
            let key = PhoneKey.make(from: number) ?? number
            if seen.insert(key).inserted { result.append(number) }
        }
        return result
    }

    private static func unionCaseInsensitive(_ lhs: [String], _ rhs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in lhs + rhs where seen.insert(value.lowercased()).inserted {
            result.append(value)
        }
        return result
    }
}

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
