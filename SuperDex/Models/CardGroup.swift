//
//  CardGroup.swift
//  HomeScreen
//

import SwiftUI

struct CardGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorName: String
    var icon: String
    var descriptionText: String?
    var eventDate: Date?
    var location: String?
    var link: String?
    var wallpaperData: Data?
    var members: [GroupMember] = []

    private static let colorMap: [String: Color] = [
        "indigo": .indigo
    ]
    static let colorNames: [String] = Array(colorMap.keys)
    static let icons: [String] = [
        "person.2.fill"
    ]

    var color: Color {
        Self.colorMap[colorName] ?? .blue
    }

    init(
        id: UUID = UUID(),
        name: String,
        colorName: String? = nil,
        icon: String? = nil,
        descriptionText: String? = nil,
        eventDate: Date? = nil,
        location: String? = nil,
        link: String? = nil,
        wallpaperData: Data? = nil,
        members: [GroupMember] = []
    ) {
        self.id = id
        self.name = name
        self.colorName = colorName ?? Self.colorNames.randomElement()!
        self.icon = icon ?? Self.icons.randomElement()!
        self.descriptionText = descriptionText
        self.eventDate = eventDate
        self.location = location
        self.link = link
        self.wallpaperData = wallpaperData
        self.members = members
    }

    var profileCards: [ProfileCard] {
        members.map { $0.asProfileCard }
    }
}
