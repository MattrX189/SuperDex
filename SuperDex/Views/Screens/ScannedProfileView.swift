//
//  ScannedProfileView.swift
//  SuperDex
//

import SwiftUI

struct ScannedProfileView: View {
    let scannedUsername: String
    var addToGroupId: UUID? = nil

    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(HomeViewModel.self) private var home
    @Environment(\.dismiss) private var dismiss

    @State private var saveState: SaveState = .idle
    @State private var fetchedProfile: UserProfileData?
    @State private var fetchedUserId: UUID?
    @State private var isLoading = true
    @State private var fetchError: String?

    private let profileService = ProfileService()

    enum SaveState {
        case idle, saving, saved, alreadyExists, failed(String)
    }

    /// After saving: "Share your card back?" (card_share.sql).
    enum ShareState: Equatable {
        case asking, sharing, shared, alreadyConnected, failed
        /// One-time: offer to make sharing automatic from now on.
        case tip
    }
    /// The share happened automatically (auto-share is on).
    @State private var sharedAutomatically = false
    @State private var shareState: ShareState?

    var body: some View {
        ZStack {
            AppBackground()

            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                                Text("Loading profile…")
                                    .font(.gilroy(.regular, size: 15))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.top, 80)
                        } else if let profile = fetchedProfile {
                            ProfileCardView(profile: profile.asProfileCard)
                                .aspectRatio(300.0 / 460.0, contentMode: .fit)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)

                            if let shareState {
                                sharePrompt(shareState, name: profile.firstName)
                                    .padding(.horizontal, 20)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            } else {
                                saveButton
                                    .padding(.horizontal, 20)
                            }

                            if case .alreadyExists = saveState {
                                Label("This contact already exists.", systemImage: "info.circle.fill")
                                    .font(.gilroy(.medium, size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 20)
                            }

                            if case .failed(let message) = saveState {
                                Text(message)
                                    .font(.gilroy(.regular, size: 13))
                                    .foregroundStyle(.red.opacity(0.85))
                                    .padding(.horizontal, 20)
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "person.slash")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text(fetchError ?? "Profile not found.")
                                    .font(.gilroy(.regular, size: 15))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.top, 80)
                        }

                        Spacer(minLength: 24)
                    }
                }
                .navigationTitle("Scanned Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
                .task {
                    do {
                        try await Task.sleep(for: .milliseconds(300))
                        if let result = try await profileService.fetchMaskedByUsername(scannedUsername) {
                            fetchedUserId = result.userId
                            fetchedProfile = result.profile

                            if contactsVM.contactExists(contactUserId: result.userId) {
                                saveState = .alreadyExists
                            }
                        }
                    } catch {
                        fetchError = error.localizedDescription
                    }
                    withAnimation {
                        isLoading = false
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 10) {
                if case .saving = saveState {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: saveIcon)
                        .font(.gilroy(.semiBold, size: 17))
                }

                Text(saveLabel)
                    .font(.gilroy(.semiBold, size: 16))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaveDisabled)
    }

    private var saveIcon: String {
        switch saveState {
        case .saved: return "checkmark.circle.fill"
        case .alreadyExists: return "person.fill.checkmark"
        default: return "person.crop.circle.badge.plus"
        }
    }

    private var saveLabel: String {
        switch saveState {
        case .idle: return addToGroupId == nil ? "Save to My Contacts" : "Add to Deck & Contacts"
        case .saving: return "Saving…"
        case .saved: return "Saved"
        case .alreadyExists: return "Already in Contacts"
        case .failed: return "Try Again"
        }
    }

    private var isSaveDisabled: Bool {
        switch saveState {
        case .saving, .saved, .alreadyExists: return true
        default: return false
        }
    }

    // MARK: - Share your card back

    private func sharePrompt(_ state: ShareState, name: String) -> some View {
        let who = name.trimmingCharacters(in: .whitespaces).isEmpty ? "them" : name
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return VStack(alignment: .leading, spacing: 14) {
            Label("Saved to your contacts", systemImage: "checkmark.circle.fill")
                .font(.gilroy(.semiBold, size: 13))
                .foregroundStyle(.green.opacity(0.9))

            switch state {
            case .asking, .sharing, .failed:
                Text("Want to share your card with \(who) too?")
                    .font(.gilroy(.bold, size: 20))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(state == .failed
                     ? "Couldn't share right now. Try again, or skip for now."
                     : "\(who) gets a request to add you to their SuperDex contacts. Skip it and they won't see your details.")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(state == .failed ? 0.75 : 0.6))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        finishOrShowTip()
                    } label: {
                        Text("Not now")
                            .font(.gilroy(.semiBold, size: 15))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(.white.opacity(0.1)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await shareMyCard() }
                    } label: {
                        HStack(spacing: 8) {
                            if state == .sharing {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "person.crop.rectangle.badge.plus")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text("Share my card")
                                .font(.gilroy(.semiBold, size: 15))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.white))
                    }
                    .buttonStyle(.plain)
                }
                .disabled(state == .sharing)

            case .shared:
                Text("Card shared with \(who)")
                    .font(.gilroy(.bold, size: 20))
                    .foregroundStyle(.white)
                Text(sharedAutomatically
                     ? "Auto-share is on, so \(who) got a request to add you. Change it anytime from My Card."
                     : "They'll get a request to add you.")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

            case .tip:
                Label("Tip", systemImage: "lightbulb.fill")
                    .font(.gilroy(.semiBold, size: 13))
                    .foregroundStyle(.yellow.opacity(0.9))
                Text("Share your card automatically?")
                    .font(.gilroy(.bold, size: 20))
                    .foregroundStyle(.white)
                Text("Turn on auto-share and your card goes out whenever you add someone. They still choose whether to add you. You can change this anytime from My Card.")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Text("Keep asking")
                            .font(.gilroy(.semiBold, size: 15))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(.white.opacity(0.1)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        contactsVM.setAutoShareCard(true)
                        dismiss()
                    } label: {
                        Text("Turn on auto-share")
                            .font(.gilroy(.semiBold, size: 15))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(.white))
                    }
                    .buttonStyle(.plain)
                }

            case .alreadyConnected:
                Text("\(who) already has your card")
                    .font(.gilroy(.bold, size: 20))
                    .foregroundStyle(.white)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(Color.white.opacity(0.06)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .animation(.snappy, value: state)
    }

    private func shareMyCard() async {
        guard let receiverId = fetchedUserId else { return }
        withAnimation { shareState = .sharing }
        let result = await contactsVM.shareCard(with: receiverId)
        switch result {
        case .sent:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation { shareState = .shared }
        case .alreadyConnected:
            withAnimation { shareState = .alreadyConnected }
        case .failed:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation { shareState = .failed }
            return
        }
        try? await Task.sleep(for: .seconds(sharedAutomatically ? 1.8 : 1.1))
        finishOrShowTip()
    }

    /// After the first Share / Not now, explain auto-share once; otherwise close.
    private func finishOrShowTip() {
        guard !contactsVM.hasSeenShareTip, !contactsVM.autoShareCard else {
            dismiss()
            return
        }
        contactsVM.markShareTipSeen()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { shareState = .tip }
    }

    private func save() async {
        guard let contactUserId = fetchedUserId else { return }
        saveState = .saving

        let ok = await contactsVM.addByReference(contactUserId: contactUserId)
        if ok {
            if let groupId = addToGroupId, let profile = fetchedProfile {
                let member = GroupMember(from: profile.asProfileCard.masked(for: .qr), userId: contactUserId)
                home.addMembers([member], toGroupId: groupId)
            }
            saveState = .saved

            // One scan, two decisions: now offer your card back — or just
            // share it if they've chosen auto-share.
            try? await Task.sleep(for: .seconds(0.4))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if contactsVM.autoShareCard {
                sharedAutomatically = true
                await shareMyCard()
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { shareState = .asking }
            }
        } else {
            if contactsVM.errorMessage == "already_exists" {
                saveState = .alreadyExists
            } else {
                saveState = .failed(contactsVM.errorMessage ?? "Failed to save contact.")
            }
        }
    }
}
