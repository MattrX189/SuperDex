//
//  DeviceContact.swift
//  SuperDex
//
//  The device address book, matched against SuperDex by phone number.
//  A `DeviceContact` is what iOS gives us; a `DeviceContactEntry` is that
//  contact after the phone-match RPC has run, so the UI knows whether to
//  render a SuperDex card or an "Invite" row.
//

import Foundation

// MARK: - Phone keys

/// Canonical form used to compare a device number against a stored profile
/// number. Numbers reach us in every shape people type them — "+91 98765
/// 43210", "098765-43210", "(555) 100-2001" — and profiles store them as
/// "+91 9876543210", so both sides reduce to digits and keep the last 10.
/// Ten is the significant-digit length for the markets SuperDex ships in and
/// drops the country code, which is exactly the part that varies between how
/// someone saved a number and how its owner typed it.
///
/// `superdex_phone_key()` in phone_contact_match.sql applies the same rule
/// server-side — change one and you must change the other.
enum PhoneKey {
    static let significantDigits = 10

    /// Nil when the input has no usable digits (empty field, "N/A", etc.).
    static func make(from raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        guard digits.count > significantDigits else { return digits }
        return String(digits.suffix(significantDigits))
    }
}

// MARK: - Device contact

/// One person from the device address book. Deliberately a value type with no
/// CNContact reference so it can cross actor boundaries freely.
struct DeviceContact: Identifiable, Hashable {
    /// CNContact.identifier — stable for the life of the address-book entry.
    let id: String
    var givenName: String
    var familyName: String
    var organizationName: String
    var jobTitle: String
    /// As stored on the device, for display and for `tel:` / `sms:` links.
    var phoneNumbers: [String]
    var emails: [String]
    /// Address-book photo, when the contact has one.
    var thumbnail: Data?

    var name: String {
        let full = [givenName, familyName]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")
        if !full.isEmpty { return full }
        if !organizationName.isEmpty { return organizationName }
        return phoneNumbers.first ?? "No Name"
    }

    /// Up to two letters for the fallback avatar.
    var initials: String {
        let letters = [givenName, familyName]
            .compactMap { $0.trimmingCharacters(in: .whitespaces).first }
            .map(String.init)
        if !letters.isEmpty { return letters.joined().uppercased() }
        return name.first.map { String($0).uppercased() } ?? "?"
    }

    var primaryPhone: String { phoneNumbers.first ?? "" }
    var primaryEmail: String { emails.first ?? "" }

    /// "Job Title at Company", dropping whichever side is empty.
    var roleLine: String {
        let role = jobTitle.trimmingCharacters(in: .whitespaces)
        let org = organizationName.trimmingCharacters(in: .whitespaces)
        switch (role.isEmpty, org.isEmpty) {
        case (false, false): return "\(role) at \(org)"
        case (false, true):  return role
        case (true, false):  return org
        case (true, true):   return ""
        }
    }

    /// Every number reduced to a comparison key, de-duplicated.
    var matchKeys: [String] {
        var seen = Set<String>()
        return phoneNumbers.compactMap { PhoneKey.make(from: $0) }
            .filter { seen.insert($0).inserted }
    }
}

// MARK: - Matched entry

/// A device contact after the phone lookup: either they're on SuperDex (and we
/// have their public card) or they're someone to invite.
struct DeviceContactEntry: Identifiable, Hashable {
    let device: DeviceContact
    /// The lean, server-masked card for a matched user. Nil = not on SuperDex.
    var match: PhoneMatchedProfile?

    var id: String { device.id }
    var isOnSuperDex: Bool { match != nil }
    var name: String { match?.card.name ?? device.name }

    /// What lands in a group. Matched people carry their SuperDex user id so
    /// the member stays linked to a real profile; everyone else is stored as
    /// a plain name/phone/email member, which groups already support.
    var asGroupMember: GroupMember {
        guard let match else {
            return GroupMember(
                name: device.name,
                jobRole: device.roleLine,
                phone: device.primaryPhone,
                email: device.primaryEmail
            )
        }
        return GroupMember(
            userId: match.userId,
            name: match.card.name,
            jobRole: match.card.jobRole,
            phone: device.primaryPhone,
            email: device.primaryEmail,
            themeName: match.card.theme.name,
            avatar: match.card.avatar
        )
    }
}

/// The slice of a profile the phone-match lookup returns. Deliberately thin:
/// matching on a number you happen to have saved proves nothing about a
/// relationship, so the server sends identity only — no phone, email or
/// links. Connect first; the full card follows.
struct PhoneMatchedProfile: Hashable {
    let userId: UUID
    let card: ProfileCard
}
