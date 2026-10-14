//
//  HomeViewModel.swift
//  HomeScreen
//

import SwiftUI
import Supabase
import Auth

@MainActor
@Observable
final class HomeViewModel {
    var searchText = ""
    var groups: [CardGroup] = []
    var showingNewGroupSheet = false
    var selectedGroup: CardGroup?
    var selectedProfile: ProfileCard?
    var groupBeingEdited: CardGroup?
    var groupPendingDeletion: CardGroup?
    var isLoading = false
    var errorMessage: String?

    private let service = GroupService()
    private(set) var currentUserId: UUID?

    var filteredGroups: [CardGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return groups }
        return groups.filter { Self.group($0, matches: query) }
    }

    /// Shared group search (Home search and the Deck tab): name,
    /// description, location, member names and event date.
    static func group(_ group: CardGroup, matches query: String) -> Bool {
        if group.name.localizedCaseInsensitiveContains(query) { return true }
        if let desc = group.descriptionText, desc.localizedCaseInsensitiveContains(query) { return true }
        if let location = group.location, location.localizedCaseInsensitiveContains(query) { return true }
        if group.members.contains(where: { $0.name.localizedCaseInsensitiveContains(query) }) { return true }
        if let date = group.eventDate,
           searchDateText(for: date).localizedCaseInsensitiveContains(query) {
            return true
        }
        return false
    }

    private static let searchDateFormatters: [DateFormatter] = {
        let dateOnly = DateFormatter(); dateOnly.dateFormat = "EEE, MMM d, yyyy"
        let timeOnly = DateFormatter(); timeOnly.dateFormat = "h:mm a"
        let monthYear = DateFormatter(); monthYear.dateFormat = "MMMM yyyy"
        return [dateOnly, timeOnly, monthYear]
    }()

    private static func searchDateText(for date: Date) -> String {
        searchDateFormatters.map { $0.string(from: date) }.joined(separator: " ")
    }

    func load(for user: User) async {
        if currentUserId == user.id { return }

        currentUserId = user.id
        isLoading = true
        defer { isLoading = false }

        do {
            groups = try await service.fetchAll(userId: user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshGroupMembers(groupId: UUID) async {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else { return }
        do {
            groups[idx].members = try await service.refreshedMembers(for: groups[idx].members)
            upsertRemote(groups[idx])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearOnSignOut() {
        currentUserId = nil
        groups = []
        selectedGroup = nil
        selectedProfile = nil
        searchText = ""
    }

    func createGroup(
        name: String,
        description: String?,
        eventDate: Date?,
        location: String? = nil,
        link: String? = nil,
        wallpaperData: Data?,
        members: [GroupMember] = []
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let trimmedDescription = description?.trimmingCharacters(in: .whitespaces)
        let group = CardGroup(
            name: trimmedName,
            descriptionText: trimmedDescription?.isEmpty == false ? trimmedDescription : nil,
            eventDate: eventDate,
            location: Self.normalized(location),
            link: Self.normalized(link),
            wallpaperData: wallpaperData,
            members: members
        )
        groups.append(group)
        upsertRemote(group)
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    @discardableResult
    func addMembers(_ newMembers: [GroupMember], toGroupId groupId: UUID) -> Int {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else { return 0 }
        var existingNames = Set(groups[idx].members.map { $0.name.lowercased() })
        var added = 0
        for member in newMembers where !existingNames.contains(member.name.lowercased()) {
            groups[idx].members.append(member)
            existingNames.insert(member.name.lowercased())
            added += 1
        }
        if added > 0 {
            upsertRemote(groups[idx])
        }
        return added
    }

    func removeMembers(_ memberIds: Set<UUID>, fromGroupId groupId: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupId }) else { return }
        groups[idx].members.removeAll { memberIds.contains($0.id) }
        if selectedGroup?.id == groupId { selectedGroup = groups[idx] }
        upsertRemote(groups[idx])
    }

    func prepareNewGroup() {
        showingNewGroupSheet = true
    }

    // MARK: - Event decks

    /// Creates a deck carrying an event's details — name, date, place,
    /// link, description and image. Used when the user confirms they're
    /// attending (EventDetailView) and from Deck's "Happening this week".
    /// Returns false when a deck for this event already exists (nothing
    /// is created then).
    func createGroup(for event: AppEvent, description: String?) async -> Bool {
        guard group(for: event) == nil else { return false }

        let place = [event.venue, event.city]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        var text = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            text = place.isEmpty
                ? "People I met at this event."
                : "People I met at \(place)."
        } else if text.count > 280 {
            text = String(text.prefix(280)) + "…"
        }

        let wallpaperData = await Self.groupWallpaperData(from: event.imageURL)
        // Re-check: the user may have created it while the image downloaded.
        guard group(for: event) == nil else { return false }

        createGroup(
            name: event.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: text,
            eventDate: event.startDate,
            location: place,
            link: event.registrationURL.absoluteString,
            wallpaperData: wallpaperData
        )
        return true
    }

    /// Downloads the event image and downscales it so the group row
    /// in Supabase stays small (wallpapers are stored base64-inline).
    private static func groupWallpaperData(from url: URL?) async -> Data? {
        guard let url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }

        let maxSide: CGFloat = 1024
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: 0.8) }

        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    /// The deck named after an event, if the user already made one
    /// (same name match EventDetailView uses).
    func group(for event: AppEvent) -> CardGroup? {
        let name = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return groups.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func updateGroup(
        id: UUID,
        name: String,
        description: String?,
        eventDate: Date?,
        location: String? = nil,
        link: String? = nil,
        wallpaperData: Data?
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }

        let trimmedDescription = description?.trimmingCharacters(in: .whitespaces)
        groups[idx].name = trimmedName
        groups[idx].descriptionText = (trimmedDescription?.isEmpty == false) ? trimmedDescription : nil
        groups[idx].eventDate = eventDate
        groups[idx].location = Self.normalized(location)
        groups[idx].link = Self.normalized(link)
        groups[idx].wallpaperData = wallpaperData

        if selectedGroup?.id == id { selectedGroup = groups[idx] }

        upsertRemote(groups[idx])
    }

    func deleteGroup(id: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        let removed = groups.remove(at: idx)
        if selectedGroup?.id == removed.id { selectedGroup = nil }
        if groupBeingEdited?.id == removed.id { groupBeingEdited = nil }
        deleteRemote(removed.id)
    }

    private func upsertRemote(_ group: CardGroup) {
        guard let userId = currentUserId else { return }
        Task { [service] in
            do {
                try await service.upsert(group, userId: userId)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteRemote(_ id: UUID) {
        guard let userId = currentUserId else { return }
        Task { [service] in
            do {
                try await service.delete(id: id, userId: userId)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
