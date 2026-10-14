//
//  SupabaseManager.swift
//  SuperDex
//

import Foundation
import Security
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://krgighgbudwalorlbsrs.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtyZ2lnaGdidWR3YWxvcmxic3JzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0NDMzNTEsImV4cCI6MjA5MjAxOTM1MX0.hd1Lbgw7zhKfVJYK-dTii23NvPNSa6Wgji9mTLXeX_0"
}

enum SupabaseManager {
    static let client: SupabaseClient = {
        // Must run before the client reads its stored session.
        FreshInstall.clearStaleKeychainIfNeeded()
        return SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }()
}

/// iOS keeps Keychain items after an app is deleted, so Supabase's saved
/// session would silently log the user back in after a reinstall. UserDefaults
/// *is* wiped on delete, so a missing marker there means this is a fresh
/// install and any session in the Keychain is left over from before.
private enum FreshInstall {
    private static let markerKey = "superdex.installMarker"

    static func clearStaleKeychainIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: markerKey) else { return }
        defaults.set(true, forKey: markerKey)

        // Existing users updating from a build without the marker also have no
        // marker — but their app container is old. Only wipe when the container
        // was just created, i.e. a genuine (re)install.
        guard isContainerNew else { return }

        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]
        SecItemDelete(query as CFDictionary)
    }

    private static var isContainerNew: Bool {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let created = (try? FileManager.default.attributesOfItem(atPath: documents.path))?[.creationDate] as? Date
        else { return true }
        return Date().timeIntervalSince(created) < 60 * 60
    }
}
