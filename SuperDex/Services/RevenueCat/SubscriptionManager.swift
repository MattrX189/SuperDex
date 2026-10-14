//
//  SubscriptionManager.swift
//  SuperDex
//
//  Modern Observable wrapper around RevenueCat. Inject once at the App level
//  with `.environment(SubscriptionManager())` and read `isPro` from any view.
//

import Foundation
import Observation
import RevenueCat

@Observable
@MainActor
final class SubscriptionManager {

    // MARK: - Public state

    /// True when the user has the `SuperDex Pro` entitlement active.
    private(set) var isPro: Bool = false

    /// Latest `CustomerInfo` from RevenueCat. `nil` until the first fetch completes.
    private(set) var customerInfo: CustomerInfo?

    /// Latest `Offerings` snapshot. The default offering powers the paywall.
    private(set) var offerings: Offerings?

    /// Set while a purchase / restore is in flight. UI can disable buttons.
    private(set) var isProcessing: Bool = false

    /// True when a purchase is awaiting external approval — e.g. India's
    /// RBI UPI autopay mandate, or Ask to Buy. The App Store completes
    /// the transaction asynchronously (minutes to hours later); the
    /// customerInfoStream listener picks it up and unlocks Pro
    /// automatically. This is NOT a failure state.
    private(set) var isPaymentPending: Bool = false

    /// Most recent surfaced error. UI can present once and clear.
    var lastError: PurchaseError?

    /// True when Apple couldn't charge the payment method for a renewal
    /// (e.g. a revoked UPI autopay mandate or an expired card). During
    /// Apple's billing grace period the entitlement can still be active,
    /// so this is the window to prompt the user before they silently
    /// lose Pro. RevenueCat clears billingIssueDetectedAt once resolved.
    var hasBillingIssue: Bool {
        customerInfo?.entitlements[RevenueCatConfig.entitlementID]?.billingIssueDetectedAt != nil
    }

    /// Apple's page for fixing the payment method behind a subscription.
    static let updatePaymentURL = URL(string: "https://apps.apple.com/account/billing")!

    // MARK: - Lifecycle

    private var listenerTask: Task<Void, Never>?

    init() {
        startListening()
        Task { await refresh() }
    }

    /// Call exactly once from `App.init`. Safe to call multiple times.
    static func configure() {
        guard !Purchases.isConfigured else { return }
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
    }

    // MARK: - Identity (Supabase ↔ RevenueCat)

    /// Link the RevenueCat app user ID to the authenticated Supabase user.
    /// Whether RevenueCat has returned authoritative customer info at least once
    /// after identify. Guards against writing stale `false` to the database.
    private(set) var hasSynced: Bool = false

    func identify(userID: String) async {
        hasSynced = false
        do {
            let (info, _) = try await Purchases.shared.logIn(userID)
            apply(customerInfo: info)

            // `logIn` only reads RevenueCat's server-side record for this user ID —
            // it does NOT re-scan the on-device App Store receipt. So a genuine
            // subscriber can come back as non-Pro after a reinstall, a new device,
            // or repeated sandbox log-out/in (the purchase isn't yet linked to this
            // app-user-ID). Reconcile against the StoreKit receipt before we trust a
            // `false`, otherwise the app would wrongly downgrade them in the DB and
            // drop them off Discover until they manually tap Restore.
            if !isPro {
                await reconcileWithAppStoreReceipt()
            }
            hasSynced = true
        } catch {
            lastError = PurchaseError(error)
        }
    }

    /// Posts the on-device App Store receipt to RevenueCat to recover any active
    /// entitlement not yet linked to the current user. Silent (no Apple ID prompt)
    /// and non-fatal: if it fails (e.g. offline) we keep whatever `logIn` returned.
    private func reconcileWithAppStoreReceipt() async {
        do {
            let info = try await Purchases.shared.syncPurchases()
            apply(customerInfo: info)
        } catch {
            // Best-effort reconcile; leave existing state untouched.
        }
    }

    /// Reset RevenueCat identity on sign-out.
    func logOut() async {
        hasSynced = false
        do {
            let info = try await Purchases.shared.logOut()
            apply(customerInfo: info)
        } catch {
            if (error as? RevenueCat.ErrorCode) != .logOutAnonymousUserError {
                lastError = PurchaseError(error)
            }
        }
    }

    // MARK: - Data

    /// Pull the latest customer info + offerings.
    func refresh() async {
        async let infoTask = try? Purchases.shared.customerInfo()
        async let offeringsTask = try? Purchases.shared.offerings()
        let (info, fetched) = await (infoTask, offeringsTask)
        if let info {
            apply(customerInfo: info)
            hasSynced = true
        }
        if let fetched { offerings = fetched }
    }

    /// The offering used for paywalls. Falls back to the dashboard default.
    var currentOffering: Offering? {
        if let id = RevenueCatConfig.offeringIdentifier {
            return offerings?.offering(identifier: id) ?? offerings?.current
        }
        return offerings?.current
    }

    // MARK: - Purchases

    /// Returns true on a successful, non-cancelled purchase that grants Pro.
    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return false }
            apply(customerInfo: result.customerInfo)
            return result.customerInfo.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
        } catch {
            switch error as? RevenueCat.ErrorCode {
            // UPI autopay mandates (India) and Ask to Buy surface as
            // paymentPendingError: the user still has to approve in their
            // UPI/bank app and the transaction completes later. Showing
            // "Purchase failed" here is wrong — flag it as pending and let
            // the customerInfoStream listener unlock Pro when it lands.
            case .paymentPendingError:
                isPaymentPending = true

            // User backed out, or tapped Subscribe twice while the first
            // purchase was still running — not errors, show nothing.
            case .purchaseCancelledError, .operationAlreadyInProgressForProductError:
                break

            // Already subscribed (e.g. on another device / family member's
            // purchase) — sync instead of erroring.
            case .productAlreadyPurchasedError:
                await reconcileWithAppStoreReceipt()

            default:
                lastError = PurchaseError(error)
            }
            return false
        }
    }

    /// Restore purchases. Required by App Review for any paid app.
    @discardableResult
    func restore() async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
            return info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
        } catch {
            switch error as? RevenueCat.ErrorCode {
            // No purchases on this Apple ID — the caller already shows
            // "No active subscription found", an alert on top is noise.
            case .missingReceiptFileError, .purchaseCancelledError:
                break
            default:
                lastError = PurchaseError(error)
            }
            return false
        }
    }

    // MARK: - Private

    private func startListening() {
        listenerTask?.cancel()
        listenerTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.apply(customerInfo: info) }
            }
        }
    }

    private func apply(customerInfo info: CustomerInfo) {
        self.customerInfo = info
        self.isPro = info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
        if isPro { isPaymentPending = false }
    }
}

// MARK: - Friendly error wrapper

struct PurchaseError: Error, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let underlying: Error

    init(_ error: Error) {
        self.underlying = error
        guard let rcError = error as? RevenueCat.ErrorCode else {
            self.title = "Something went wrong"
            self.message = error.localizedDescription
            return
        }

        switch rcError {
        case .networkError, .offlineConnectionError:
            title = "No Connection"
            message = "Check your internet connection and try again."

        case .storeProblemError:
            title = "App Store Unavailable"
            message = "The App Store is having a temporary problem. Your payment was not charged — please try again in a few minutes."

        case .purchaseNotAllowedError:
            title = "Purchases Not Allowed"
            message = "Purchases are restricted on this device. Check Screen Time or parental control settings."

        case .purchaseInvalidError:
            title = "Payment Method Issue"
            message = "The App Store couldn't process your payment method. Please verify your payment details in your Apple Account settings."

        case .productNotAvailableForPurchaseError:
            title = "Not Available"
            message = "This plan isn't available in your region's App Store right now."

        case .receiptAlreadyInUseError:
            title = "Linked to Another Account"
            message = "This subscription is already linked to a different SuperDex account. Log in with that account, or contact support."

        case .invalidPromotionalOfferError, .ineligibleError:
            title = "Offer Not Available"
            message = "You're not eligible for this offer. Please choose a regular plan."

        default:
            title = "Purchase Failed"
            message = "Something went wrong and your payment didn't complete. You have not been charged — please try again."
        }
    }
}
