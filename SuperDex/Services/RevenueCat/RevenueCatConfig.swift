//
//  RevenueCatConfig.swift
//  SuperDex
//
//  Single source of truth for RevenueCat identifiers. Update values here
//  and they propagate to the manager, paywall, and entitlement checks.
//

import Foundation

enum RevenueCatConfig {

    /// Public SDK key from the RevenueCat dashboard → Project settings → API keys.
    /// Use the `appl_...` key under "SDK API keys" → "SuperDex (App Store)".
    /// ⚠️  Replace this placeholder before shipping.
    static let apiKey = "appl_XwcvpZWholTrLFZINHXJbOkmsuF"

    /// Entitlement identifier configured in the RevenueCat dashboard.
    /// Any active subscription that grants this entitlement unlocks Pro features.
    static let entitlementID = "SuperDex Pro"

    /// Offering identifier — leave as `nil` to use the dashboard's default offering.
    /// Override to A/B-test alternate paywalls or per-segment offerings.
    static let offeringIdentifier: String? = nil

    /// Product identifiers — must match App Store Connect product IDs exactly.
    enum Product {
        static let yearly = "rc_annual"
        static let monthly = "rc_monthly"
    }

    /// External links shown in the paywall footer.
    static let termsURL = URL(string: "https://www.superdex.in/terms")!
    static let privacyURL = URL(string: "https://www.superdex.in/privacy")!
    static let supportEmail = URL(string: "mailto:support@superdex.in")!
    static let appStoreSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}
