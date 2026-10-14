//
//  GigDetailView.swift
//  SuperDex
//
//  Full page for one gig post: description, poster, apply with an
//  optional pitch — or, for the poster, applicant review and post
//  management. Report/block wiring per Guideline 1.2.
//

import SwiftUI

struct GigDetailView: View {
    // Held in @State so the page reflects the owner's edits without
    // needing to pop back to the feed.
    @State private var post: GigPost
    let viewModel: GigsViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(ContactRequestViewModel.self) private var requestVM
    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(BlockStore.self) private var blockStore
    @Environment(SubscriptionManager.self) private var subscription

    @State private var pitchMessage = ""
    @State private var isApplying = false
    @State private var applyError: String?
    @State private var hasApplied: Bool
    @State private var showWithdrawPrompt = false
    @State private var showFreeApplyPrompt = false
    @State private var showPaywall = false
    @State private var showApplicantsSheet = false
    @State private var showClosePrompt = false
    @State private var showEditSheet = false
    @State private var reportReason: ReportReason?
    @State private var reportSubmitted = false

    private var accent: Color { .indigo }
    private var isOwn: Bool { post.isOwn(viewModel.currentUserId) }

    init(post: GigPost, viewModel: GigsViewModel) {
        _post = State(initialValue: post)
        self.viewModel = viewModel
        _hasApplied = State(initialValue: post.hasApplied)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Color.clear.frame(height: 56)

                    titleSection

                    descriptionCard

                    posterCard

                    if isOwn {
                        ownerSection
                    } else {
                        applySection
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 20)
            }

            topBar
                .padding(.horizontal, 20)
                .padding(.top, 4)
        }
        .background {
            pageBackground.ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showApplicantsSheet) {
            GigApplicantsSheet(post: post, viewModel: viewModel)
        }
        .sheet(isPresented: $showEditSheet) {
            // After saving, pull the refreshed row back into this page.
            if let updated = viewModel.posts.first(where: { $0.id == post.id }) {
                post = updated
            }
        } content: {
            GigComposerSheet(viewModel: viewModel, editingPost: post)
        }
        .confirmationDialog(
            "Close this post?",
            isPresented: $showClosePrompt,
            titleVisibility: .visible
        ) {
            Button("Close post", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task {
                    await viewModel.closePost(post)
                    dismiss()
                }
            }
            Button("Keep it open", role: .cancel) {}
        } message: {
            Text("It disappears from the feed for everyone. You can still see your applicants for 30 days.")
        }
        .alert("Apply without Pro?", isPresented: $showFreeApplyPrompt) {
            Button("Upgrade to Pro") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPaywall = true
            }
            Button("Apply Anyway") {
                apply()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only your name, job title, company and bio will be visible to the recruiter. Upgrade to Pro to also show them your portfolio.")
        }
        .paywallSheet(isPresented: $showPaywall)
        .confirmationDialog(
            "Withdraw application?",
            isPresented: $showWithdrawPrompt,
            titleVisibility: .visible
        ) {
            Button("Withdraw", role: .destructive) {
                Task {
                    await viewModel.withdraw(from: post)
                    hasApplied = false
                }
            }
            Button("Keep application", role: .cancel) {}
        }
        .alert(
            "Report this post?",
            isPresented: Binding(
                get: { reportReason != nil },
                set: { if !$0 { reportReason = nil } }
            ),
            presenting: reportReason
        ) { reason in
            Button("Report", role: .destructive) {
                submitReport(reason)
            }
            Button("Cancel", role: .cancel) {}
        } message: { reason in
            Text("Reports it as \"\(reason.label)\". We review reports within 24 hours.")
        }
        .alert("Thanks for the report", isPresented: $reportSubmitted) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We'll review this post within 24 hours.")
        }
    }

    // MARK: - Report / block

    private func submitReport(_ reason: ReportReason) {
        guard let reporterId = viewModel.currentUserId else { return }
        Task {
            try? await ModerationService().submitReport(
                reporterId: reporterId,
                reportedUserId: post.userId,
                reason: reason,
                details: "Gig post: \"\(post.title)\" (\(post.id.uuidString))"
            )
            reportSubmitted = true
        }
    }

    // MARK: - Background / top bar

    private var pageBackground: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)

            LinearGradient(
                colors: [accent.opacity(0.45), accent.opacity(0.15), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            if !isOwn {
                Menu {
                    Section("Report this post") {
                        ForEach(ReportReason.selectable) { reason in
                            Button(reason.label) { reportReason = reason }
                        }
                    }
                    Button(role: .destructive) {
                        blockStore.block(id: post.userId, name: post.posterFullName)
                        submitReport(.blocked)
                        dismiss()
                    } label: {
                        Label("Block \(post.posterFirstName)", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .menuOrder(.fixed)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(post.title)
                .font(.gilroy(.bold, size: 28))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let category = post.category {
                HStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(category.displayName)
                        .font(.gilroy(.semiBold, size: 12))
                        .tracking(1.0)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(accent.opacity(0.35)))
                .overlay(Capsule().strokeBorder(accent.opacity(0.7), lineWidth: 1))
            }

            HStack(spacing: 10) {
                if let budget = post.budgetText {
                    glassChip(icon: "tag.fill", text: budget)
                }
                if let duration = post.durationText {
                    glassChip(icon: "clock.fill", text: duration)
                }
                if let location = post.location {
                    glassChip(icon: "mappin.and.ellipse", text: location)
                }
            }

            // Applicant count is private to the poster.
            Text(isOwn ? "Posted \(post.postedAgo) · \(applicantsText)" : "Posted \(post.postedAgo)")
                .font(.gilroy(.medium, size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var applicantsText: String {
        switch post.applicantCount {
        case 0:  return "no applicants yet"
        case 1:  return "1 applicant"
        default: return "\(post.applicantCount) applicants"
        }
    }

    private func glassChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
            Text(text)
                .font(.gilroy(.semiBold, size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    // MARK: - Description / poster

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About this requirement")
                .font(.gilroy(.semiBold, size: 14))
                .foregroundStyle(.white.opacity(0.45))

            Text(post.descriptionText)
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    /// The poster's role + company as one uppercase line, matching
    /// GlassContactRow's job-role treatment.
    private var posterRoleLine: String {
        [post.posterJobRole, post.posterCompanyName]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
            .uppercased()
    }

    // Same look as GlassContactRow in Contacts, minus the call/mail
    // buttons; the Connect pill sits in their place.
    private var posterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Posted by")
                .font(.gilroy(.semiBold, size: 13))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 4)

            HStack(alignment: .center, spacing: 14) {
                if post.posterAvatar.isEmpty {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 56, height: 56)
                } else {
                    Image(post.posterAvatar)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(post.posterFullName)
                        .font(.gilroy(.semiBold, size: 19))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !posterRoleLine.isEmpty {
                        Text(posterRoleLine)
                            .font(.gilroy(.semiBold, size: 11))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }

                    if !post.posterBio.isEmpty {
                        Text(post.posterBio)
                            .font(.gilroy(.regular, size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 4)

                if !isOwn {
                    DiscoverConnectPill(
                        state: posterConnectState,
                        action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task { await requestVM.sendRequest(to: post.userId) }
                        },
                        onWithdraw: {
                            Task { await requestVM.withdrawRequest(to: post.userId) }
                        }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        }
    }

    private var posterConnectState: DiscoverConnectState {
        if contactsVM.contactExists(contactUserId: post.userId) { return .connected }
        switch requestVM.sentStatuses[post.userId] {
        case .pending:          return .pending
        case .accepted:         return .connected
        case .rejected, .none:  return .connect
        }
    }

    // MARK: - Apply (everyone else)

    @ViewBuilder
    private var applySection: some View {
        if hasApplied {
            VStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showWithdrawPrompt = true
                } label: {
                    heroButtonLabel(
                        icon: "checkmark.seal.fill",
                        title: "You've Applied",
                        color: Color(red: 0.15, green: 0.65, blue: 0.40)
                    )
                }
                .buttonStyle(GroupCardPressStyle())

                Text("The poster can see your name, role, company and bio. Tap to withdraw.")
                    .font(.gilroy(.regular, size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your pitch (optional)")
                    .font(.gilroy(.semiBold, size: 13))
                    .foregroundStyle(.white.opacity(0.55))

                TextField(
                    "",
                    text: $pitchMessage,
                    prompt: Text("Why are you a great fit?")
                        .font(.gilroy(.regular, size: 15))
                        .foregroundColor(.white.opacity(0.35)),
                    axis: .vertical
                )
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white)
                .tint(.white)
                .lineLimit(3...6)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )

                if let applyError {
                    Text(applyError)
                        .font(.gilroy(.medium, size: 13))
                        .foregroundStyle(.red.opacity(0.9))
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if subscription.isPro {
                        apply()
                    } else {
                        // Free members get a heads-up about what the poster
                        // will (and won't) see before the application goes out.
                        showFreeApplyPrompt = true
                    }
                } label: {
                    heroButtonLabel(
                        icon: isApplying ? nil : "paperplane.fill",
                        title: isApplying ? "Applying…" : "Apply for this Opportunity",
                        color: accent,
                        showsSpinner: isApplying
                    )
                }
                .buttonStyle(GroupCardPressStyle())
                .disabled(isApplying)

                Text("Applying shares your name, role, company and bio with the poster.")
                    .font(.gilroy(.regular, size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func apply() {
        let message = pitchMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if let term = ContentModeration.firstObjectionableTerm(in: message) {
            applyError = "\"\(term)\" isn't allowed in a pitch. Please reword it."
            return
        }
        applyError = nil
        isApplying = true
        Task {
            do {
                try await viewModel.apply(to: post, message: message.isEmpty ? nil : message)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                hasApplied = true
            } catch {
                applyError = "Couldn't apply — the opportunity may have closed. Pull to refresh and try again."
            }
            isApplying = false
        }
    }

    // MARK: - Owner tools

    private var ownerSection: some View {
        VStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showApplicantsSheet = true
            } label: {
                heroButtonLabel(
                    icon: "person.2.fill",
                    title: post.applicantCount == 0
                        ? "No Applicants Yet"
                        : "View \(post.applicantCount) Applicant\(post.applicantCount == 1 ? "" : "s")",
                    color: accent
                )
            }
            .buttonStyle(GroupCardPressStyle())

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showEditSheet = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Edit")
                            .font(.gilroy(.semiBold, size: 14))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showClosePrompt = true
                } label: {
                    Text("Close post")
                        .font(.gilroy(.semiBold, size: 14))
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func heroButtonLabel(
        icon: String?,
        title: String,
        color: Color,
        showsSpinner: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            if showsSpinner {
                ProgressView().tint(.white)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
            }

            Text(title)
                .font(.gilroy(.bold, size: 16))
                .tracking(0.5)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            LinearGradient(
                colors: [color, color.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: color.opacity(0.5), radius: 16, y: 8)
    }
}
