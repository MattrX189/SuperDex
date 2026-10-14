//
//  NotificationsViewModel.swift
//  SuperDex
//
//  The in-app notifications feed: loads the user's notifications, keeps
//  the unread count for the bell, listens over Realtime for new ones and
//  raises a banner for each while the app is open.
//

import SwiftUI
import Supabase
import Auth
import Realtime

@MainActor
@Observable
final class NotificationsViewModel {
    private(set) var items: [AppNotification] = [] {
        // App-icon badge always matches unread notifications.
        didSet { PushNotificationManager.shared.setBadge(unreadCount) }
    }
    private(set) var hasLoaded = false
    /// The banner currently showing at the top of the screen, if any.
    var banner: AppNotification?
    /// Drives the Notifications sheet (opened from the bell or a banner).
    var isPresented = false

    var unreadCount: Int { items.count { $0.isUnread } }

    private let service = NotificationsService()
    private var currentUserId: UUID?
    private var realtimeTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func load(for user: User) async {
        currentUserId = user.id
        await refresh()
        startRealtime(userId: user.id)
    }

    func refresh() async {
        guard let userId = currentUserId else { return }
        do {
            items = try await service.fetch(userId: userId)
            hasLoaded = true
        } catch {
            #if DEBUG
            print("[Notifications] fetch failed: \(error)")
            #endif
        }
    }

    func clearOnSignOut() {
        realtimeTask?.cancel()
        realtimeTask = nil
        bannerTask?.cancel()
        currentUserId = nil
        items = []
        banner = nil
        isPresented = false
        hasLoaded = false
    }

    // MARK: - Read state

    func markAllRead() {
        guard let userId = currentUserId, unreadCount > 0 else { return }
        let now = Date()
        for index in items.indices where items[index].readAt == nil {
            items[index].readAt = now
        }
        Task { try? await service.markAllRead(userId: userId) }
    }

    /// Quietly drop a notification (e.g. declining a shared card). The
    /// other person is never told.
    func remove(_ notification: AppNotification) {
        withAnimation(.snappy) { items.removeAll { $0.id == notification.id } }
        Task { try? await service.delete(id: notification.id) }
    }

    // MARK: - Banner

    func open(from notification: AppNotification? = nil) {
        dismissBanner()
        isPresented = true
    }

    func dismissBanner() {
        bannerTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { banner = nil }
    }

    private func showBanner(_ notification: AppNotification) {
        // The sheet already shows it; no banner on top of it.
        guard !isPresented else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { banner = notification }
        bannerTask?.cancel()
        bannerTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            dismissBanner()
        }
    }

    // MARK: - Realtime

    private func startRealtime(userId: UUID) {
        realtimeTask?.cancel()
        realtimeTask = Task {
            let channel = SupabaseManager.client.realtimeV2.channel(
                "superdex-notifications-\(userId.uuidString)"
            )
            let inserts = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "notifications",
                filter: .eq("user_id", value: userId.uuidString)
            )
            await channel.subscribe()
            for await _ in inserts {
                guard !Task.isCancelled else { break }
                let known = Set(items.map(\.id))
                await refresh()
                if let newest = items.first(where: { !known.contains($0.id) }) {
                    showBanner(newest)
                }
            }
            await channel.unsubscribe()
        }
    }
}
