//
//  MeetingHistoryView.swift
//  HomeScreen
//
//  Created by Gaurang Pant on 17/04/26.
//

import SwiftUI

/// "Interactions" — every time you met someone and what you talked about,
/// newest first, as a vertical timeline.
struct MeetingHistoryView: View {
    let meetings: [EventMeeting]
    var contactUserId: UUID? = nil
    var personName: String? = nil
    var accent: Color = Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0)
    var showBackground: Bool = true
    var onAdd: ((EventMeeting) async -> Void)? = nil
    var onEdit: ((EventMeeting) async -> Void)? = nil
    var onDelete: ((EventMeeting) async -> Void)? = nil
    @State private var showingAddMeeting = false
    @State private var meetingToEdit: EventMeeting?
    @State private var addByVoice = true

    private var canAddMeetings: Bool { contactUserId != nil && onAdd != nil }

    private var sortedMeetings: [EventMeeting] { meetings.sorted(by: { $0.date > $1.date }) }

    private var firstName: String {
        personName?.split(separator: " ").first.map(String.init) ?? "this person"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if meetings.isEmpty {
                        emptyStateView
                    } else {
                        Text("How you know \(firstName)")
                            .font(.gilroy(.bold, size: 24))
                            .foregroundStyle(.white)
                            .padding(.bottom, 4)
                        Text("\(meetings.count) interaction\(meetings.count == 1 ? "" : "s") · long-press to edit")
                            .font(.gilroy(.medium, size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.bottom, 20)

                        ForEach(Array(sortedMeetings.enumerated()), id: \.element.id) { index, meeting in
                            MeetingTimelineRow(
                                meeting: meeting,
                                accent: accent,
                                isFirst: index == 0,
                                isLast: index == sortedMeetings.count - 1
                            )
                            .contextMenu {
                                if onEdit != nil {
                                    Button {
                                        meetingToEdit = meeting
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                }
                                if onDelete != nil {
                                    Button(role: .destructive) {
                                        Task { await onDelete?(meeting) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 64)
                .padding(.bottom, canAddMeetings ? 110 : 20)
            }

            if canAddMeetings && !meetings.isEmpty {
                addButton
                    .padding(.bottom, 20)
            }
        }
        .background { if showBackground { AppBackground() } }
        .sheet(isPresented: $showingAddMeeting) {
            AddMeetingView(personName: personName, startsWithVoice: addByVoice) { newMeeting in
                Task { await onAdd?(newMeeting) }
            }
        }
        .sheet(item: $meetingToEdit) { meeting in
            AddMeetingView(meeting: meeting, personName: personName) { updated in
                Task { await onEdit?(updated) }
            }
        }
    }

    private var addButton: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                addByVoice = true
                showingAddMeeting = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Record an interaction")
                        .font(.gilroy(.semiBold, size: 16))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .frame(height: 52)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                addByVoice = false
                showingAddMeeting = true
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Type an interaction")
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(.bottom, 6)

            Text("How do you know \(firstName)?")
                .font(.gilroy(.bold, size: 22))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Jot down where you met and what you talked about — so next time, you pick up right where you left off.")
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if canAddMeetings {
                addButton
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

/// One interaction on the timeline: dot + connecting line on the left, card on the right.
private struct MeetingTimelineRow: View {
    let meeting: EventMeeting
    let accent: Color
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isFirst ? accent : Color.white.opacity(0.25))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(accent.opacity(isFirst ? 0.35 : 0), lineWidth: 6))
                    .padding(.top, 20)
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            MeetingCard(meeting: meeting, accent: accent)
                .padding(.bottom, isLast ? 0 : 14)
        }
    }
}

struct MeetingCard: View {
    let meeting: EventMeeting
    var accent: Color = .white

    private var notes: String { meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(meeting.placeName ?? "Interaction")
                    .font(.gilroy(.bold, size: 17))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer(minLength: 8)

                Text(meeting.date.interactionAgoText)
                    .font(.gilroy(.semiBold, size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }

            if !meeting.eventName.isEmpty && !meeting.location.isEmpty {
                Label(meeting.location, systemImage: "mappin.and.ellipse")
                    .font(.gilroy(.medium, size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, -6)
            }

            if !notes.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Capsule()
                        .fill(accent.opacity(0.8))
                        .frame(width: 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOU TALKED ABOUT")
                            .font(.gilroy(.semiBold, size: 10))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.4))
                        Text(notes)
                            .font(.gilroy(.medium, size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(3)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    MeetingHistoryView(meetings: EventMeeting.sampleMeetings, personName: "Abhinav Maharana")
}

#Preview("Empty State") {
    MeetingHistoryView(meetings: [], personName: "Abhinav Maharana")
}
