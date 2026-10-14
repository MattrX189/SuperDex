//
//  ContactRequestService.swift
//  SuperDex
//

import Foundation
import Supabase

struct ContactRequestService {
    private let client = SupabaseManager.client

    /// Upsert a pending request from the current user to receiverId.
    func sendRequest(receiverId: UUID) async throws -> RequestStatus {
        struct Params: Encodable { let p_receiver_id: String }
        let raw: String = try await client
            .rpc("send_contact_request", params: Params(p_receiver_id: receiverId.uuidString))
            .execute()
            .value
        return RequestStatus(rawValue: raw) ?? .pending
    }

    /// Accept or reject a pending request. On accept the server inserts the sender
    /// into the contacts table so they see the receiver in their contacts.
    func respond(requestId: UUID, accept: Bool) async throws {
        struct Params: Encodable { let p_request_id: String; let p_accept: Bool }
        try await client
            .rpc("respond_to_contact_request",
                 params: Params(p_request_id: requestId.uuidString, p_accept: accept))
            .execute()
    }

    /// Withdraw a pending request the current user sent to receiverId.
    func withdrawRequest(receiverId: UUID) async throws {
        struct Params: Encodable { let p_receiver_id: String }
        try await client
            .rpc("withdraw_contact_request", params: Params(p_receiver_id: receiverId.uuidString))
            .execute()
    }

    /// Undo a connection: removes both people from each other's contacts and
    /// any request between them (see disconnect_contact.sql).
    func disconnect(otherUserId: UUID) async throws {
        struct Params: Encodable { let p_other_id: String }
        try await client
            .rpc("disconnect_contact", params: Params(p_other_id: otherUserId.uuidString))
            .execute()
    }

    /// Pending requests where the current user is the receiver.
    func fetchPendingRequests() async throws -> [ContactRequest] {
        let rows: [PendingRow] = try await client
            .rpc("get_my_pending_requests")
            .execute()
            .value
        return rows.map { $0.toContactRequest() }
    }

    /// Status of every request the current user has sent.
    func fetchSentStatuses() async throws -> [UUID: RequestStatus] {
        let rows: [SentRow] = try await client
            .rpc("get_my_sent_requests")
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            guard let status = RequestStatus(rawValue: row.status) else { return nil }
            return (row.receiver_id, status)
        })
    }
}

// MARK: - Codable row types

private struct PendingRow: Codable {
    let request_id: UUID
    let sender_id: UUID
    let first_name: String
    let last_name: String
    let avatar: String
    let job_role: String
    let company_name: String
    let requested_at: Date

    func toContactRequest() -> ContactRequest {
        ContactRequest(
            id: request_id,
            senderId: sender_id,
            firstName: first_name,
            lastName: last_name,
            avatar: avatar,
            jobRole: job_role,
            companyName: company_name,
            requestedAt: requested_at
        )
    }
}

private struct SentRow: Codable {
    let receiver_id: UUID
    let status: String
}
