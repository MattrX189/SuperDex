//
//  ContactRequest.swift
//  SuperDex
//

import Foundation

struct ContactRequest: Identifiable {
    let id: UUID
    let senderId: UUID
    let firstName: String
    let lastName: String
    let avatar: String
    let jobRole: String
    let companyName: String
    let requestedAt: Date

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
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
        let seconds = Date().timeIntervalSince(requestedAt)
        switch seconds {
        case ..<60:     return "Just now"
        case ..<3600:   return "\(Int(seconds / 60))m ago"
        case ..<86400:  return "\(Int(seconds / 3600))h ago"
        case ..<604800: return "\(Int(seconds / 86400))d ago"
        default:        return "\(Int(seconds / 604800))w ago"
        }
    }
}

enum RequestStatus: String, Codable {
    case pending
    case accepted
    case rejected
}
