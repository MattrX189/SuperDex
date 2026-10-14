//
//  ContactRequestViewModel.swift
//  SuperDex
//

import SwiftUI
import Supabase
import Auth
import Realtime

@MainActor
@Observable
final class ContactRequestViewModel {
    var pendingRequests: [ContactRequest] = []
    var sentStatuses:    [UUID: RequestStatus] = [:]
    var isLoading = false
    var errorMessage: String?

    var pendingCount: Int { pendingRequests.count }

    private let service = ContactRequestService()
    private(set) var currentUserId: UUID?
    private var realtimeTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func load(for user: User) async {
        currentUserId = user.id
        await refresh()
        startRealtime(userId: user.id)
    }

    func refresh() async {
        guard currentUserId != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let pending = service.fetchPendingRequests()
            async let sent    = service.fetchSentStatuses()
            pendingRequests = try await pending
            sentStatuses    = try await sent
            errorMessage    = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearOnSignOut() {
        realtimeTask?.cancel()
        realtimeTask = nil
        currentUserId = nil
        pendingRequests = []
        sentStatuses = [:]
    }

    // MARK: - Actions

    @discardableResult
    func sendRequest(to receiverId: UUID) async -> RequestStatus {
        do {
            let status = try await service.sendRequest(receiverId: receiverId)
            sentStatuses[receiverId] = status
            return status
        } catch {
            errorMessage = error.localizedDescription
            return .pending
        }
    }

    /// Withdraw a pending request the current user sent, so the receiver
    /// no longer sees it and the sender can re-connect later.
    func withdrawRequest(to receiverId: UUID) async {
        do {
            try await service.withdrawRequest(receiverId: receiverId)
            sentStatuses.removeValue(forKey: receiverId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Undo an accepted connection, so the pill goes back to "Connect".
    /// Callers should refresh ContactsViewModel afterwards.
    func disconnect(from otherUserId: UUID) async {
        do {
            try await service.disconnect(otherUserId: otherUserId)
            sentStatuses.removeValue(forKey: otherUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respond(to requestId: UUID, accept: Bool) async {
        do {
            try await service.respond(requestId: requestId, accept: accept)
            pendingRequests.removeAll { $0.id == requestId }
            if accept {
                // Mark the sender as accepted in sentStatuses on this device too
                // (only relevant if the receiver is also the original sender, which
                // can't happen — this line is kept for defensive completeness).
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Realtime

    private func startRealtime(userId: UUID) {
        realtimeTask?.cancel()
        realtimeTask = Task {
            let channel = SupabaseManager.client.realtimeV2.channel(
                "superdex-cr-\(userId.uuidString)"
            )
            let inserts = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "contact_requests",
                filter: .eq("receiver_id", value: userId.uuidString)
            )
            await channel.subscribe()
            for await _ in inserts {
                guard !Task.isCancelled else { break }
                await refresh()
            }
            await channel.unsubscribe()
        }
    }
}
