//
//  EventAttendeesSheet.swift
//  SuperDex
//
//  Full list of SuperDex users attending an event, styled like
//  ProfileViewersSheet / the contacts list. Presented from the
//  "Who's going" card in EventDetailView. Shows only the masked
//  attendee fields (name, job title, company, bio) — the full card
//  unlocks in Contacts once a connect request is accepted.
//

import SwiftUI

struct EventAttendeesSheet: View {
    let eventTitle: String
    let attendees: [EventAttendee]
    let currentUserId: UUID?

    @Environment(ContactRequestViewModel.self) private var requestVM
    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(\.dismiss) private var dismiss

    // MARK: - Connect state

    private func connectState(for attendee: EventAttendee) -> DiscoverConnectState {
        if contactsVM.contactExists(contactUserId: attendee.id) { return .connected }
        switch requestVM.sentStatuses[attendee.id] {
        case .pending:          return .pending
        case .accepted:         return .connected
        case .rejected, .none:  return .connect
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerText
                        .padding(.horizontal, 20)
                        .padding(.top, 28)

                    attendeeList
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                }
            }
            .background(AppBackground())

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
                    .glassEffect(.clear.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, 24)
        }
        .preferredColorScheme(.dark)
        .task {
            await requestVM.refresh()
        }
    }

    // MARK: - Header

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Who's Going")
                .font(.gilroy(.bold, size: 34))
                .foregroundStyle(.white)

            Text(subtitleText)
                .font(.gilroy(.medium, size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var subtitleText: String {
        switch attendees.count {
        case 1:  return "1 person from SuperDex is going to \"\(eventTitle)\"."
        default: return "\(attendees.count) people from SuperDex are going to \"\(eventTitle)\"."
        }
    }

    // MARK: - List

    private var attendeeList: some View {
        LazyVStack(spacing: 12) {
            ForEach(attendees) { attendee in
                attendeeRow(attendee)
            }
        }
    }

    private func attendeeRow(_ attendee: EventAttendee) -> some View {
        HStack(alignment: .top, spacing: 14) {
            avatarView(attendee)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(attendee.fullName)
                        .font(.gilroy(.bold, size: 16))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if attendee.id == currentUserId {
                        Text("You")
                            .font(.gilroy(.semiBold, size: 10))
                            .tracking(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green.opacity(0.30)))
                            .overlay(Capsule().strokeBorder(Color.green.opacity(0.65), lineWidth: 1))
                    }
                }

                if !attendee.subtitle.isEmpty {
                    Text(attendee.subtitle)
                        .font(.gilroy(.medium, size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                if !attendee.bio.isEmpty {
                    Text(attendee.bio)
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 8)

            if attendee.id == currentUserId {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.15, green: 0.65, blue: 0.40))
                    .padding(.top, 14)
            } else {
                DiscoverConnectPill(
                    state: connectState(for: attendee),
                    action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await requestVM.sendRequest(to: attendee.id) }
                    },
                    onWithdraw: {
                        Task { await requestVM.withdrawRequest(to: attendee.id) }
                    }
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func avatarView(_ attendee: EventAttendee) -> some View {
        if attendee.avatar.isEmpty {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.white.opacity(0.06)))
                .clipShape(Circle())
        } else {
            Image(attendee.avatar)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.white.opacity(0.06)))
                .clipShape(Circle())
        }
    }
}

#Preview {
    EventAttendeesSheet(
        eventTitle: "Developer Days Bengaluru",
        attendees: [
            EventAttendee(
                id: UUID(),
                firstName: "Gaurang",
                lastName: "Pant",
                avatar: "memoji1",
                jobRole: "Founder",
                companyName: "Mattr",
                bio: "Building SuperDex"
            ),
            EventAttendee(
                id: UUID(),
                firstName: "Tester",
                lastName: "",
                avatar: "memoji2",
                jobRole: "",
                companyName: "",
                bio: ""
            )
        ],
        currentUserId: nil
    )
    .environment(ContactRequestViewModel())
    .environment(ContactsViewModel())
    .preferredColorScheme(.dark)
}
