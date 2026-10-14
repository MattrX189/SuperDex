//
//  FeedbackService.swift
//  SuperDex
//

import Foundation
import Supabase

struct FeatureRequest: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let title: String
    let description: String
    var upvoteCount: Int
    let createdAt: Date
    var hasUpvoted: Bool
    var isOwn: Bool
}

struct FeedbackService {
    private let client = SupabaseManager.client

    // MARK: - Bug reports

    func submitBugReport(userId: UUID, title: String, description: String) async throws {
        let row = BugReportInsert(user_id: userId, title: title, description: description)
        try await client.from("bug_reports").insert(row).execute()
    }

    // MARK: - Feature requests

    func submitFeatureRequest(userId: UUID, title: String, description: String) async throws -> UUID {
        let row = FeatureRequestInsert(user_id: userId, title: title, description: description)
        let inserted: [FeatureRequestRow] = try await client
            .from("feature_requests")
            .insert(row)
            .select()
            .execute()
            .value
        return inserted.first?.id ?? UUID()
    }

    func fetchFeatureRequests(currentUserId: UUID) async throws -> [FeatureRequest] {
        async let allRows: [FeatureRequestRow] = client
            .from("feature_requests")
            .select()
            .order("upvote_count", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value

        async let userVotes: [UpvoteRow] = client
            .from("feature_upvotes")
            .select("feature_request_id")
            .eq("user_id", value: currentUserId)
            .execute()
            .value

        let (rows, votes) = try await (allRows, userVotes)
        let votedIds = Set(votes.map(\.feature_request_id))

        return rows.map { row in
            FeatureRequest(
                id: row.id,
                userId: row.user_id,
                title: row.title,
                description: row.description,
                upvoteCount: row.upvote_count,
                createdAt: row.created_at,
                hasUpvoted: votedIds.contains(row.id),
                isOwn: row.user_id == currentUserId
            )
        }
    }

    func upvote(featureRequestId: UUID, userId: UUID) async throws {
        let row = UpvoteInsert(feature_request_id: featureRequestId, user_id: userId)
        try await client.from("feature_upvotes").insert(row).execute()
    }

    func removeUpvote(featureRequestId: UUID, userId: UUID) async throws {
        try await client
            .from("feature_upvotes")
            .delete()
            .eq("feature_request_id", value: featureRequestId)
            .eq("user_id", value: userId)
            .execute()
    }
}

// MARK: - Row models

private struct BugReportInsert: Encodable {
    let user_id: UUID
    let title: String
    let description: String
}

private struct FeatureRequestInsert: Encodable {
    let user_id: UUID
    let title: String
    let description: String
}

private struct FeatureRequestRow: Decodable {
    let id: UUID
    let user_id: UUID
    let title: String
    let description: String
    let upvote_count: Int
    let created_at: Date
}

private struct UpvoteInsert: Encodable {
    let feature_request_id: UUID
    let user_id: UUID
}

private struct UpvoteRow: Decodable {
    let feature_request_id: UUID
}
