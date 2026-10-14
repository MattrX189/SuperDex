//
//  NotificationsSheet.swift
//  SuperDex
//
//  In-app notifications: the feed behind Home's bell, and the banner that
//  slides in from the top when one arrives while the app is open.
//

import SwiftUI

private let notificationAccent = Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0)

// MARK: - Feed

struct NotificationsSheet: View {
    @Environment(NotificationsViewModel.self) private var notifications
    @Environment(ContactRequestViewModel.self) private var requestVM
    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(\.dismiss) private var dismiss

    /// Profile opened by tapping a notification.
    @State private var profileToOpen: ProfileLink?
    /// Requests being answered right now (spinner on their buttons).
    @State private var responding: Set<UUID> = []
    /// Shared cards being added right now.
    @State private var adding: Set<UUID> = []

    private struct ProfileLink: Identifiable {
        let username: String
        var id: String { username }
    }

    private var newItems: [AppNotification] { notifications.items.filter(\.isUnread) }
    private var earlierItems: [AppNotification] { notifications.items.filter { !$0.isUnread } }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if notifications.items.isEmpty {
                        emptyState
                            .padding(.top, 80)
                    } else {
                        if !newItems.isEmpty {
                            section("New", items: newItems)
                        }
                        if !earlierItems.isEmpty {
                            section("Earlier", items: earlierItems)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(AppBackground())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if notifications.unreadCount > 0 {
                        Button("Mark all read") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.snappy) { notifications.markAllRead() }
                        }
                        .font(.gilroy(.semiBold, size: 14))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.gilroy(.semiBold, size: 15))
                }
            }
            .refreshable {
                await notifications.refresh()
                await requestVM.refresh()
            }
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .task { await requestVM.refresh() }
        // Leaving the feed counts as having seen everything in it.
        .onDisappear { notifications.markAllRead() }
        .sheet(item: $profileToOpen) { link in
            ScannedProfileView(scannedUsername: link.username)
        }
    }

    private func section(_ title: String, items: [AppNotification]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.gilroy(.semiBold, size: 12))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 4)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    row(item)
                }
            }
        }
    }

    private func row(_ item: AppNotification) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button {
            guard !item.actorUsername.isEmpty else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            profileToOpen = ProfileLink(username: item.actorUsername)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                avatar(item)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let body = item.body, !body.isEmpty {
                        Text(body)
                            .font(.gilroy(.regular, size: 13))
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(item.createdAt.formatted(.relative(presentation: .named)))
                        .font(.gilroy(.medium, size: 11))
                        .foregroundStyle(.white.opacity(0.35))

                    if item.kind == .connectRequest {
                        requestActions(item)
                            .padding(.top, 6)
                    } else if item.kind == .cardShared {
                        cardSharedActions(item)
                            .padding(.top, 6)
                    }
                }

                Spacer(minLength: 0)

                if item.isUnread {
                    Circle()
                        .fill(notificationAccent)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Color.white.opacity(item.isUnread ? 0.07 : 0.04)))
            .overlay(shape.strokeBorder(Color.white.opacity(item.isUnread ? 0.12 : 0.07), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    private func avatar(_ item: AppNotification) -> some View {
        Image(item.actorAvatar)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 44, height: 44)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: badgeIcon(item.kind))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(notificationAccent))
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 2))
                    .offset(x: 3, y: 3)
            }
    }

    private func badgeIcon(_ kind: AppNotification.Kind) -> String {
        switch kind {
        case .connectRequest:  return "person.badge.plus"
        case .requestAccepted: return "checkmark"
        case .gigApplication:  return "briefcase.fill"
        case .cardShared:      return "person.text.rectangle.fill"
        case .other:           return "bell.fill"
        }
    }

    /// Accept / Decline right in the feed while the request is still open.
    @ViewBuilder
    private func requestActions(_ item: AppNotification) -> some View {
        if let requestId = item.requestId,
           requestVM.pendingRequests.contains(where: { $0.id == requestId }) {
            HStack(spacing: 8) {
                actionButton("Accept", filled: true, busy: responding.contains(requestId)) {
                    respond(requestId, accept: true)
                }
                actionButton("Decline", filled: false, busy: false) {
                    respond(requestId, accept: false)
                }
            }
            .disabled(responding.contains(requestId))
        } else if item.requestId != nil {
            Label("Responded", systemImage: "checkmark.circle")
                .font(.gilroy(.medium, size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func actionButton(_ title: String, filled: Bool, busy: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                if busy {
                    ProgressView().controlSize(.small).tint(.black)
                }
                Text(title)
                    .font(.gilroy(.semiBold, size: 13))
            }
            .foregroundStyle(filled ? .black : .white)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Capsule().fill(filled ? Color.white : Color.white.opacity(0.1)))
            .overlay(Capsule().strokeBorder(.white.opacity(filled ? 0 : 0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Someone who scanned you shared their card: one tap adds them.
    @ViewBuilder
    private func cardSharedActions(_ item: AppNotification) -> some View {
        if let sharerId = item.actorId {
            if contactsVM.contactExists(contactUserId: sharerId) {
                Label("In your contacts", systemImage: "checkmark.circle.fill")
                    .font(.gilroy(.medium, size: 12))
                    .foregroundStyle(.green.opacity(0.8))
            } else {
                HStack(spacing: 8) {
                    actionButton("Add to Contacts", filled: true, busy: adding.contains(sharerId)) {
                        adding.insert(sharerId)
                        Task {
                            await contactsVM.acceptSharedCard(from: sharerId)
                            adding.remove(sharerId)
                        }
                    }
                    // Declining is silent: recorded on the server so they
                    // aren't re-asked, but the sharer is never told.
                    actionButton("Not now", filled: false, busy: false) {
                        Task { await contactsVM.declineSharedCard(from: sharerId) }
                        notifications.remove(item)
                    }
                }
                .disabled(adding.contains(sharerId))
            }
        }
    }

    private func respond(_ requestId: UUID, accept: Bool) {
        responding.insert(requestId)
        Task {
            await requestVM.respond(to: requestId, accept: accept)
            if accept { await contactsVM.refresh() }
            responding.remove(requestId)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(.white.opacity(0.35))
            Text("You're all caught up")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.85))
            Text("Connect requests, cards people share with you, accepted connections and applications to your gigs will show up here.")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}

// MARK: - Banner

/// Slides in from the top when a notification arrives while the app is
/// open. Tap to open the feed; swipe up to dismiss. Shown by ContentView.
struct InAppNotificationBanner: View {
    let notification: AppNotification
    var onTap: () -> Void
    var onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(notification.actorAvatar)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.gilroy(.semiBold, size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let body = notification.body, !body.isEmpty {
                    Text(body)
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .padding(.horizontal, 12)
        .offset(y: min(dragOffset, 0))
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }
        .gesture(
            DragGesture()
                .onChanged { dragOffset = $0.translation.height }
                .onEnded { value in
                    if value.translation.height < -24 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 }
                    }
                }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
