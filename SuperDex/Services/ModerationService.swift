//
//  ModerationService.swift
//  SuperDex
//
//  Writes user reports (and block events) to the `content_reports` table.
//  This table is the developer's moderation queue — reports are reviewed and
//  acted on within 24 hours per App Store Review Guideline 1.2.
//

import Foundation
import Supabase

/// Reasons a user can flag another user's profile.
enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case inappropriate
    case impersonation
    case other
    /// Internal reason logged when a user blocks someone (not shown in the picker).
    case blocked

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam:          return "Spam or scam"
        case .harassment:    return "Harassment or bullying"
        case .inappropriate: return "Inappropriate or offensive content"
        case .impersonation: return "Impersonation or fake profile"
        case .other:         return "Something else"
        case .blocked:       return "Blocked by user"
        }
    }

    /// Reasons offered in the report UI (everything except the internal `blocked`).
    static var selectable: [ReportReason] { allCases.filter { $0 != .blocked } }
}

struct ModerationService {
    private let client = SupabaseManager.client

    func submitReport(
        reporterId: UUID,
        reportedUserId: UUID,
        reason: ReportReason,
        details: String?
    ) async throws {
        let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = ContentReportInsert(
            reporter_id: reporterId,
            reported_user_id: reportedUserId,
            reason: reason.rawValue,
            details: (trimmed?.isEmpty == false) ? trimmed : nil
        )
        try await client.from("content_reports").insert(row).execute()
    }
}

private struct ContentReportInsert: Encodable {
    let reporter_id: UUID
    let reported_user_id: UUID
    let reason: String
    let details: String?
}
