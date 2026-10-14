//
//  GigService.swift
//  SuperDex
//
//  Reads and writes gig posts + applications (see gigs.sql). Reads
//  go through masked RPCs; the poster's own post management uses
//  direct table access guarded by RLS owner policies.
//

import Foundation
import Supabase

struct GigService {
    private let client = SupabaseManager.client

    /// The open-gigs feed, newest first. nil means the fetch failed
    /// (offline, tables not deployed) — distinct from an empty feed.
    func fetchPosts() async -> [GigPost]? {
        do {
            let rows: [GigPostRow] = try await client
                .rpc("get_gig_posts")
                .execute()
                .value
            return rows.map { $0.toGigPost() }
        } catch {
            return nil
        }
    }

    func createPost(
        userId: UUID,
        title: String,
        description: String,
        category: ProfileCategory,
        budgetText: String?,
        durationText: String?,
        location: String?
    ) async throws {
        let row = GigPostInsert(
            user_id: userId,
            title: title,
            description: description,
            category: category.rawValue,
            budget_text: budgetText,
            duration_text: durationText,
            location: location
        )
        try await client.from("gig_posts").insert(row).execute()
    }

    /// Edits an existing post. Guarded by the owner RLS update
    /// policy, so only the poster can change their own row.
    func updatePost(
        postId: UUID,
        title: String,
        description: String,
        category: ProfileCategory,
        budgetText: String?,
        durationText: String?,
        location: String?
    ) async throws {
        // Send "" (not nil) for cleared fields: Swift's synthesized
        // encoder omits nil optionals, which would leave the old
        // value in place. The read path maps "" back to nil.
        let row = GigPostUpdate(
            title: title,
            description: description,
            category: category.rawValue,
            budget_text: budgetText ?? "",
            duration_text: durationText ?? "",
            location: location ?? ""
        )
        try await client
            .from("gig_posts")
            .update(row)
            .eq("id", value: postId)
            .execute()
    }

    /// Closing removes the post from everyone's feed; applications
    /// stay readable to the poster until the cleanup job deletes the
    /// post 30 days later.
    func closePost(postId: UUID) async throws {
        try await client
            .from("gig_posts")
            .update(["status": "closed"])
            .eq("id", value: postId)
            .execute()
    }

    func deletePost(postId: UUID) async throws {
        try await client
            .from("gig_posts")
            .delete()
            .eq("id", value: postId)
            .execute()
    }

    /// Applies via the apply_to_gig RPC, which enforces open/expired/
    /// own-post rules server-side. Throws with the server's message
    /// ("this gig is no longer open", ...) on rejection.
    func apply(postId: UUID, message: String?) async throws {
        struct Params: Encodable {
            let p_post_id: String
            let p_message: String?
        }
        try await client
            .rpc("apply_to_gig", params: Params(
                p_post_id: postId.uuidString,
                p_message: message
            ))
            .execute()
    }

    func withdraw(postId: UUID, userId: UUID) async throws {
        try await client
            .from("gig_applications")
            .delete()
            .eq("post_id", value: postId)
            .eq("applicant_id", value: userId)
            .execute()
    }

    /// Applicants for one of the caller's own posts (the RPC returns
    /// nothing for posts they don't own). nil on fetch failure.
    func fetchApplicants(postId: UUID) async -> [GigApplicant]? {
        do {
            let rows: [GigApplicantRow] = try await client
                .rpc("get_gig_applicants", params: ["p_post_id": postId.uuidString])
                .execute()
                .value
            return rows.map { $0.toApplicant() }
        } catch {
            return nil
        }
    }
}

// MARK: - Row models

private struct GigPostRow: Decodable {
    let id: UUID
    let user_id: UUID
    let title: String
    let description: String
    let category: String
    let budget_text: String?
    let duration_text: String?
    let location: String?
    let status: String
    let created_at: Date
    let expires_at: Date
    let poster_first_name: String
    let poster_last_name: String
    let poster_avatar: String
    let poster_job_role: String
    let poster_company_name: String
    let poster_bio: String
    let applicant_count: Int
    let has_applied: Bool

    func toGigPost() -> GigPost {
        GigPost(
            id: id,
            userId: user_id,
            title: title,
            descriptionText: description,
            category: ProfileCategory(rawValue: category),
            budgetText: budget_text?.isEmpty == true ? nil : budget_text,
            durationText: duration_text?.isEmpty == true ? nil : duration_text,
            location: location?.isEmpty == true ? nil : location,
            createdAt: created_at,
            expiresAt: expires_at,
            posterFirstName: poster_first_name,
            posterLastName: poster_last_name,
            posterAvatar: poster_avatar,
            posterJobRole: poster_job_role,
            posterCompanyName: poster_company_name,
            posterBio: poster_bio,
            applicantCount: applicant_count,
            hasApplied: has_applied
        )
    }
}

private struct GigPostInsert: Encodable {
    let user_id: UUID
    let title: String
    let description: String
    let category: String
    let budget_text: String?
    let duration_text: String?
    let location: String?
}

private struct GigPostUpdate: Encodable {
    let title: String
    let description: String
    let category: String
    let budget_text: String
    let duration_text: String
    let location: String
}

private struct GigApplicantRow: Decodable {
    let applicant_id: UUID
    let first_name: String
    let last_name: String
    let avatar: String
    let job_role: String
    let company_name: String
    let bio: String
    let message: String
    let status: String
    let applied_at: Date

    func toApplicant() -> GigApplicant {
        GigApplicant(
            id: applicant_id,
            firstName: first_name,
            lastName: last_name,
            avatar: avatar,
            jobRole: job_role,
            companyName: company_name,
            bio: bio,
            message: message,
            appliedAt: applied_at
        )
    }
}
