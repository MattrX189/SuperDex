//
//  GigModels.swift
//  SuperDex
//
//  Models for the Requirements ("Gigs") feed on Discover. A GigPost
//  carries the poster's masked card (name, avatar, job, company)
//  exactly as returned by the get_gig_posts RPC — the poster's full
//  card stays gated behind an accepted connect request.
//

import Foundation

struct GigPost: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let title: String
    let descriptionText: String
    /// nil when the stored rawValue no longer matches a ProfileCategory.
    let category: ProfileCategory?
    let budgetText: String?
    let durationText: String?
    let location: String?
    let createdAt: Date
    let expiresAt: Date

    let posterFirstName: String
    let posterLastName: String
    let posterAvatar: String
    let posterJobRole: String
    let posterCompanyName: String
    let posterBio: String

    var applicantCount: Int
    var hasApplied: Bool

    var posterFullName: String {
        [posterFirstName, posterLastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var posterSubtitle: String {
        switch (posterJobRole.isEmpty, posterCompanyName.isEmpty) {
        case (false, false): return "\(posterJobRole) at \(posterCompanyName)"
        case (false, true):  return posterJobRole
        case (true, false):  return posterCompanyName
        case (true, true):   return ""
        }
    }

    func isOwn(_ currentUserId: UUID?) -> Bool {
        userId == currentUserId
    }

    var postedAgo: String {
        // Server timestamps can sit a moment ahead of the device
        // clock, which would render as "in 0 seconds" on a fresh post.
        guard Date().timeIntervalSince(createdAt) > 60 else { return "Just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// One applicant on a gig the current user posted — the same masked
/// card shape as EventAttendee, plus their pitch message.
struct GigApplicant: Identifiable, Hashable {
    let id: UUID
    let firstName: String
    let lastName: String
    let avatar: String
    let jobRole: String
    let companyName: String
    let bio: String
    let message: String
    let appliedAt: Date

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var subtitle: String {
        switch (jobRole.isEmpty, companyName.isEmpty) {
        case (false, false): return "\(jobRole) at \(companyName)"
        case (false, true):  return jobRole
        case (true, false):  return companyName
        case (true, true):   return ""
        }
    }
}
