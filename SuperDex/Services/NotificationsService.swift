//
//  NotificationsService.swift
//  SuperDex
//
//  Reads the signed-in user's in-app notifications from
//  public.notifications. Rows are written server-side by triggers
//  (see notifications.sql); the app only reads and marks them read.
//

import Foundation
import Supabase

/// One in-app notification.
struct AppNotification: Identifiable, Hashable {
    enum Kind: String {
        case connectRequest = "connect_request"
        case requestAccepted = "request_accepted"
        case gigApplication = "gig_application"
        /// Someone who scanned you shared their card back (card_share.sql).
        case cardShared = "card_shared"
        case other
    }

    let id: UUID
    let kind: Kind
    let title: String
    let body: String?
    let actorId: UUID?
    let actorName: String
    let actorAvatar: String
    let actorUsername: String
    /// connect_request / request_accepted
    let requestId: UUID?
    /// gig_application
    let postId: UUID?
    var readAt: Date?
    let createdAt: Date

    var isUnread: Bool { readAt == nil }
}

struct NotificationsService {
    private let client = SupabaseManager.client
    private let table = "notifications"

    func fetch(userId: UUID, limit: Int = 60) async throws -> [AppNotification] {
        let rows: [NotificationRow] = try await client
            .from(table)
            .select("id, type, title, body, actor_id, data, read_at, created_at")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.map { $0.toNotification() }
    }

    /// Removes one of the user's own notifications. Only they ever see it,
    /// so nobody else learns it was dismissed.
    func delete(id: UUID) async throws {
        try await client.from(table).delete().eq("id", value: id).execute()
    }

    func markAllRead(userId: UUID) async throws {
        try await client
            .from(table)
            .update(["read_at": ISO8601DateFormatter().string(from: .now)])
            .eq("user_id", value: userId)
            .is("read_at", value: nil)
            .execute()
    }
}

private struct NotificationRow: Decodable {
    struct Payload: Decodable {
        let actor_name: String?
        let actor_avatar: String?
        let actor_username: String?
        let request_id: UUID?
        let post_id: UUID?
    }

    let id: UUID
    let type: String
    let title: String
    let body: String?
    let actor_id: UUID?
    let data: Payload?
    let read_at: Date?
    let created_at: Date

    func toNotification() -> AppNotification {
        let name = data?.actor_name?.trimmingCharacters(in: .whitespaces) ?? ""
        return AppNotification(
            id: id,
            kind: AppNotification.Kind(rawValue: type) ?? .other,
            title: title,
            body: body,
            actorId: actor_id,
            actorName: name.isEmpty ? "Someone" : name,
            actorAvatar: (data?.actor_avatar).flatMap { $0.isEmpty ? nil : $0 } ?? "memoji1",
            actorUsername: data?.actor_username ?? "",
            requestId: data?.request_id,
            postId: data?.post_id,
            readAt: read_at,
            createdAt: created_at
        )
    }
}
