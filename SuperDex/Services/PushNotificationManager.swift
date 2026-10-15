//
//  PushNotificationManager.swift
//  SuperDex
//
//  iOS side of push notifications:
//  • asks permission (once the user reaches Home) and registers with APNs,
//  • saves this device's token to Supabase for the signed-in user
//    (register_device_token — see push_notifications.sql) and removes it
//    on sign-out,
//  • decides how pushes look while the app is open,
//  • routes a tapped push to the Notifications screen,
//  • keeps the app-icon badge in step with unread notifications.
//
//  The pushes themselves are sent by the `send-push` Edge Function.
//

import SwiftUI
import UIKit
import UserNotifications
import Supabase

@MainActor
@Observable
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    /// Set when the user taps a push; ContentView opens the feed and clears it.
    var pendingOpenNotifications = false

    private var deviceToken: String?
    private var currentUserId: UUID?

    private var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    // MARK: - Permission & registration

    /// Shows the system prompt the first time; afterwards just re-registers
    /// (tokens can change), so it's safe to call on every launch. With
    /// `prompt: false` it never shows the prompt — only re-registers.
    func requestAuthorizationAndRegister(prompt: Bool = true) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            guard prompt else { return }
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            #if DEBUG
            print("[Push] permission \(granted ? "granted" : "denied")")
            #endif
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        case .authorized, .provisional, .ephemeral:
            #if DEBUG
            print("[Push] permission already granted — registering with APNs")
            #endif
            UIApplication.shared.registerForRemoteNotifications()
        default:
            #if DEBUG
            print("[Push] notifications are off for SuperDex (Settings → SuperDex → Notifications)")
            #endif
        }
    }

    func didRegister(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        #if DEBUG
        print("[Push] got APNs device token \(deviceToken?.prefix(12) ?? "")…")
        #endif
        Task { await uploadToken() }
    }

    func didFailToRegister(_ error: Error) {
        #if DEBUG
        print("[Push] APNs registration failed: \(error)")
        #endif
    }

    // MARK: - Account

    func setUser(_ userId: UUID?) {
        currentUserId = userId
        Task { await uploadToken() }
    }

    /// Call before the session is cleared on sign-out — removing the token
    /// needs the user's auth.
    func unregisterForSignOut() async {
        defer { currentUserId = nil }
        guard let deviceToken else { return }
        struct Params: Encodable { let p_token: String }
        _ = try? await SupabaseManager.client
            .rpc("unregister_device_token", params: Params(p_token: deviceToken))
            .execute()
        setBadge(0)
    }

    private func uploadToken() async {
        guard let deviceToken, currentUserId != nil else {
            #if DEBUG
            print("[Push] not saving token yet — token: \(deviceToken != nil), signed in: \(currentUserId != nil)")
            #endif
            return
        }
        struct Params: Encodable { let p_token: String; let p_environment: String }
        do {
            try await SupabaseManager.client
                .rpc("register_device_token", params: Params(p_token: deviceToken, p_environment: environment))
                .execute()
            #if DEBUG
            print("[Push] device token saved to Supabase (\(environment))")
            #endif
        } catch {
            #if DEBUG
            print("[Push] couldn't save device token: \(error)")
            #endif
        }
    }

    // MARK: - Badge

    func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}

// MARK: - Presentation & taps

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    // Completion-handler versions on purpose: iOS calls these off the main
    // thread, and the `async` variants on a main-actor class crash when a
    // tapped push launches the app. Only the state change hops to main.

    /// While the app is open, pushes that mirror an in-app notification are
    /// already shown by the in-app banner (NotificationsViewModel) — just
    /// add them to Notification Center. Anything else (e.g. a broadcast)
    /// gets the normal banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let mirrorsInApp = notification.request.content.userInfo["notification_id"] != nil
        completionHandler(mirrorsInApp ? [.list] : [.banner, .list, .sound])
    }

    /// A push was tapped: open the Notifications screen once the UI is up.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.pendingOpenNotifications = true
        }
        completionHandler()
    }
}

// MARK: - App delegate

/// Hooks APNs callbacks into PushNotificationManager. Attached via
/// @UIApplicationDelegateAdaptor in SuperDexApp.
final class SuperDexAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotificationManager.shared.didFailToRegister(error)
    }
}
