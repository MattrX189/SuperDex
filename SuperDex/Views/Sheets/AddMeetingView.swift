//
//  AddMeetingView.swift
//  HomeScreen
//
//  Created by Gaurang Pant on 17/04/26.
//

import SwiftUI

struct AddMeetingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var eventName: String
    @State private var location: String
    @State private var date: Date
    @State private var notes: String
    @State private var dictation = SpeechDictation()
    /// Notes as they were when the current dictation session began, so the
    /// live transcript is appended rather than replacing what's there.
    @State private var notesBeforeDictation = ""

    private let existing: EventMeeting?
    private let personName: String?
    private let startsWithVoice: Bool
    let onSave: (EventMeeting) -> Void

    init(
        meeting: EventMeeting? = nil,
        personName: String? = nil,
        startsWithVoice: Bool = false,
        onSave: @escaping (EventMeeting) -> Void
    ) {
        self.existing = meeting
        self.personName = personName
        self.startsWithVoice = startsWithVoice
        self.onSave = onSave
        _eventName = State(initialValue: meeting?.eventName ?? "")
        _location = State(initialValue: meeting?.location ?? "")
        _date = State(initialValue: meeting?.date ?? Date())
        _notes = State(initialValue: meeting?.notes ?? "")
    }

    private var isEditing: Bool { existing != nil }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What you talked about is the interaction itself; where/when are optional.
    private var canSave: Bool {
        !trimmed(notes).isEmpty
    }

    private var firstName: String {
        personName?.split(separator: " ").first.map(String.init) ?? "them"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Projects, interests, a follow-up you promised…",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(4...10)
                    .disabled(dictation.isListening)
                } header: {
                    Text("What did you talk about?")
                }

                // Own section so the notes field above keeps its rounded bottom corners.
                Section {
                    DictationControl(dictation: dictation) {
                        Task { await toggleDictation() }
                    } onOpenSettings: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .listSectionSpacing(.compact)

                Section {
                    TextField("Event or place, e.g. SuperDex Meetup", text: $eventName)
                    TextField("City or venue", text: $location)
                    DatePicker("When", selection: $date, displayedComponents: [.date])
                } header: {
                    Text("Where did you meet \(firstName)? (optional)")
                } footer: {
                    Text("Only you can see this.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(isEditing ? "Edit Interaction" : "New Interaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dictation.stop()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dictation.stop()
                        let meeting = EventMeeting(
                            id: existing?.id ?? UUID(),
                            eventName: trimmed(eventName),
                            location: trimmed(location),
                            date: date,
                            notes: trimmed(notes)
                        )
                        onSave(meeting)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? .white : .white.opacity(0.35))
                }
            }
            .onChange(of: dictation.transcript) { _, spoken in
                guard !spoken.isEmpty else { return }
                let base = trimmed(notesBeforeDictation)
                notes = base.isEmpty ? spoken : base + " " + spoken
            }
            .task {
                if startsWithVoice { await toggleDictation() }
            }
            .onDisappear { dictation.stop() }
        }
    }

    private func toggleDictation() async {
        if !dictation.isListening { notesBeforeDictation = notes }
        await dictation.toggle()
    }
}

/// Big mic button with a level-reactive pulse, plus status text.
private struct DictationControl: View {
    let dictation: SpeechDictation
    let onToggle: () -> Void
    let onOpenSettings: () -> Void

    private let accent = Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0)

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(dictation.isListening ? 0.25 : 0))
                        .frame(width: 84, height: 84)
                        .scaleEffect(1 + CGFloat(dictation.level) * 0.45)
                        .animation(.easeOut(duration: 0.12), value: dictation.level)

                    Circle()
                        .fill(dictation.isListening ? Color.red : accent)
                        .frame(width: 64, height: 64)
                        .shadow(color: (dictation.isListening ? Color.red : accent).opacity(0.5), radius: 14, y: 4)

                    if dictation.status == .requesting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: dictation.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 96, height: 96)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dictation.isListening ? "Stop dictation" : "Start dictation")

            statusText
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dictation.status)
    }

    @ViewBuilder
    private var statusText: some View {
        switch dictation.status {
        case .listening:
            Text("Listening… tap to stop")
                .font(.gilroy(.semiBold, size: 14))
                .foregroundStyle(.white)
        case .denied:
            VStack(spacing: 4) {
                Text("Mic or speech access is off")
                    .font(.gilroy(.semiBold, size: 14))
                    .foregroundStyle(.white)
                Button("Open Settings", action: onOpenSettings)
                    .font(.gilroy(.semiBold, size: 13))
                    .foregroundStyle(accent)
            }
        case .unavailable:
            Text("Dictation isn't available right now — type instead")
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.6))
        case .idle, .requesting:
            Text("Tap to speak, or type above")
                .font(.gilroy(.medium, size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

#Preview {
    AddMeetingView { meeting in
        print("Saved: \(meeting.eventName)")
    }
}
