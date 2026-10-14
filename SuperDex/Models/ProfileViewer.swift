//
//  ProfileViewer.swift
//  SuperDex
//
//  A person who viewed your card from the Discover feed.
//  Returned by the get_my_profile_viewers RPC (premium only).
//

import Foundation

struct ProfileViewer: Identifiable {
    let id: UUID            // viewer's user_id
    let firstName: String
    let lastName: String
    let avatar: String
    let jobRole: String
    let companyName: String
    let viewedAt: Date

    var fullName: String {
        let name = [firstName, lastName]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "SuperDex member" : name
    }

    var subtitle: String {
        switch (jobRole.isEmpty, companyName.isEmpty) {
        case (false, false): return "\(jobRole) · \(companyName)"
        case (false, true):  return jobRole
        case (true, false):  return companyName
        case (true, true):   return ""
        }
    }

    var relativeTime: String {
        let seconds = Date().timeIntervalSince(viewedAt)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 604_800 { return "\(Int(seconds / 86_400))d ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: viewedAt)
    }
}
