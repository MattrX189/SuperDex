//
//  ContentModeration.swift
//  SuperDex
//
//  Lightweight, offline filter for objectionable text in user-generated
//  profile fields (name, bio, company, job role, custom link title).
//  Applied when a user saves their own profile so objectionable content
//  never reaches the Discover feed in the first place — this is the
//  "method for filtering objectionable content" required by App Store
//  Review Guideline 1.2.
//

import Foundation

enum ContentModeration {

    /// Base list of objectionable terms. Kept intentionally small and focused
    /// on slurs / sexual / abusive content; extend as needed. Matching is
    /// case-insensitive and ignores common leet-speak substitutions.
    // Matched as whole words only (see `firstObjectionableTerm`), so common
    // professional terms like "analyst" or "circumstance" are never flagged.
    private static let bannedTerms: [String] = [
        // Sexual / explicit
        "porn", "pornography", "xxx", "blowjob", "handjob",
        "cumshot", "creampie", "rape", "rapist", "pedo",
        "pedophile", "molest", "incest", "bestiality", "fuck", "fucker",
        "fucking", "motherfucker", "pussy", "cunt", "whore",
        "slut",
        // Slurs / hate
        "nigger", "nigga", "faggot", "retard", "retarded", "chink",
        "kike", "tranny", "coon", "wetback",
        // Violence / illegal
        "kill yourself", "kys", "child porn", "childporn",
        // Scam / abuse signals commonly seen in spam profiles
        "onlyfans", "sexcam", "camgirl"
    ]

    /// Normalises text for matching: lowercases and folds the most common
    /// leet-speak character swaps so "f u c k" / "fuk" / "n1gger" don't slip by.
    private static func normalize(_ text: String) -> String {
        var s = text.lowercased()
        let swaps: [Character: Character] = [
            "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"
        ]
        s = String(s.map { swaps[$0] ?? $0 })
        // Collapse anything that isn't a letter so spacing / punctuation between
        // letters can't be used to evade the word list ("f.u.c.k" -> "fuck").
        let lettersOnly = s.unicodeScalars.map { CharacterSet.letters.contains($0) ? Character($0) : " " }
        return String(lettersOnly)
    }

    /// Returns the first banned term found in `text`, or nil if it's clean.
    static func firstObjectionableTerm(in text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let normalized = normalize(text)
        let collapsed = normalized.replacingOccurrences(of: " ", with: "")

        for term in bannedTerms {
            let normalizedTerm = normalize(term).replacingOccurrences(of: " ", with: "")
            guard !normalizedTerm.isEmpty else { continue }

            // Word-boundary match in the spaced form (catches standalone words)…
            let spacedPadded = " \(normalized) "
            if spacedPadded.contains(" \(normalizedTerm) ") {
                return term
            }
            // …and a substring match in the fully collapsed form (catches
            // spacing-based evasion like "f u c k").
            if collapsed.contains(normalizedTerm) {
                return term
            }
        }
        return nil
    }

    /// Convenience: true if any of the supplied fields contains objectionable text.
    static func containsObjectionable(_ fields: String...) -> Bool {
        fields.contains { firstObjectionableTerm(in: $0) != nil }
    }
}
