//
//  ProfileDetailView.swift
//  HomeScreen
//
//  Created by Gaurang Pant on 15/04/26.
//

import SwiftUI
import Auth

struct ProfileDetailView: View {
    let profile: ProfileCard
    var isUserProfile: Bool = false
    var isDiscovery: Bool = false
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM
    @Environment(HomeViewModel.self) private var home
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(ContactRequestViewModel.self) private var contactRequestVM
    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(BlockStore.self) private var blockStore
    @State private var showReport = false
    @State private var showBlockConfirm = false
    @State private var showRemoveConfirm = false
    @State private var showSaveToContacts = false
    @State private var showEditProfile = false
    @State private var showPrivacySettings = false
    @State private var showActivity = false
    @State private var showAddInteraction = false
    @State private var addInteractionByVoice = true
    @State private var showPaywall = false
    @State private var shareUIImage: UIImage?
    @State private var meetings: [EventMeeting] = []
    @State private var selectedImageIndex: Int?
    @State private var isSendingRequest = false
    @State private var showWithdrawRequestConfirm = false

    private let meetingService = MeetingService()

    private var isOnyx: Bool {
        profile.theme.name == "Onyx"
    }

    private var accent: Color {
        isOnyx ? .white : (profile.theme.gradientColors.first ?? .purple)
    }

    private var accentSecondary: Color {
        isOnyx ? Color(white: 0.85) : (profile.theme.gradientColors.last ?? .purple)
    }

    var body: some View {
        profileTabContent
            .background { backgroundLayer }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            navBar
                .padding(.horizontal, 20)
                .padding(.top, 6)
        }
        .navigationDestination(isPresented: $showActivity) {
            MeetingHistoryView(
                meetings: meetings,
                contactUserId: profile.contactUserId,
                personName: profile.name,
                accent: accent,
                showBackground: false,
                onAdd: { meeting in
                    await addMeeting(meeting)
                },
                onEdit: { meeting in
                    await editMeeting(meeting)
                },
                onDelete: { meeting in
                    await deleteMeeting(meeting)
                }
            )
            .navigationTitle("Interactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .background(AppBackground())
        }
        .sheet(isPresented: $showAddInteraction) {
            AddMeetingView(personName: profile.name, startsWithVoice: addInteractionByVoice) { meeting in
                Task { await addMeeting(meeting) }
            }
        }
        .sheet(isPresented: $showSaveToContacts) {
            SaveToContactsView(profile: profile) {
                showSaveToContacts = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
        }
        .navigationDestination(isPresented: $showPrivacySettings) {
            PrivacyVisibilityView()
        }
        .fullScreenCover(item: Binding(
            get: { selectedImageIndex.map { PortfolioViewerIndex(index: $0) } },
            set: { selectedImageIndex = $0?.index }
        )) { item in
            PortfolioViewer(
                images: profile.portfolioImages,
                currentIndex: item.index,
                onDismiss: { selectedImageIndex = nil },
                onOpenLink: { url in openURL(url) }
            )
        }
        .paywallSheet(isPresented: $showPaywall)
        .task {
            if !isUserProfile && !isDiscovery {
                await loadMeetings()
            }
        }
        .task(id: shareCardSignature) {
            if isUserProfile {
                renderShareImage()
            }
        }
    }

    private func loadMeetings() async {
        guard let userId = authVM.currentUser?.id,
              let contactUserId = profile.contactUserId else { return }
        do {
            meetings = try await meetingService.fetchAll(userId: userId, contactUserId: contactUserId)
        } catch {
            print("Failed to load meetings: \(error.localizedDescription)")
        }
    }

    private func addMeeting(_ meeting: EventMeeting) async {
        guard let userId = authVM.currentUser?.id,
              let contactUserId = profile.contactUserId else { return }
        do {
            try await meetingService.insert(meeting, userId: userId, contactUserId: contactUserId)
            meetings.insert(meeting, at: 0)
        } catch {
            print("Failed to save meeting: \(error.localizedDescription)")
        }
    }

    private func editMeeting(_ meeting: EventMeeting) async {
        guard let userId = authVM.currentUser?.id,
              let contactUserId = profile.contactUserId else { return }
        do {
            try await meetingService.update(meeting, userId: userId, contactUserId: contactUserId)
            if let idx = meetings.firstIndex(where: { $0.id == meeting.id }) {
                meetings[idx] = meeting
            }
        } catch {
            print("Failed to update meeting: \(error.localizedDescription)")
        }
    }

    private func deleteMeeting(_ meeting: EventMeeting) async {
        guard let userId = authVM.currentUser?.id else { return }
        do {
            try await meetingService.delete(id: meeting.id, userId: userId)
            meetings.removeAll { $0.id == meeting.id }
        } catch {
            print("Failed to delete meeting: \(error.localizedDescription)")
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        AppBackground(showTopGlow: false)
            .ignoresSafeArea()
    }

    private var cardGlow: some View {
        ZStack {
            RadialGradient(
                colors: [
                    accent.opacity(0.50),
                    accent.opacity(0.20),
                    accent.opacity(0.05),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.15),
                startRadius: 40,
                endRadius: 700
            )

            RadialGradient(
                colors: [
                    accentSecondary.opacity(0.30),
                    accentSecondary.opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.85, y: 0.12),
                startRadius: 20,
                endRadius: 500
            )
            .blendMode(.plusLighter)
        }
        .frame(height: 900)
        .offset(y: -100)
        .allowsHitTesting(false)
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .glassEffect(.clear.interactive(), in: Circle())
            }

            Spacer()

            if isUserProfile {
                HStack(spacing: 10) {
                    shareNavButton

                    if profile.isPremiumUser {
                        Button {
                            showPrivacySettings = true
                        } label: {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .glassEffect(.clear.interactive(), in: Circle())
                        }
                    }
                    Button {
                        showEditProfile = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .glassEffect(.clear.interactive(), in: Circle())
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button {
                        showSaveToContacts = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .glassEffect(.clear.interactive(), in: Circle())
                    }

                    if isDiscovery {
                        connectButton
                    }

                    if !isDiscovery {
                        Button {
                            showActivity = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                Text("Interactions")
                                if !meetings.isEmpty {
                                    Text("\(meetings.count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white, in: Capsule())
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .glassEffect(.clear.interactive(), in: Capsule())
                        }
                    }

                    moreMenu
                }
            }
        }
    }

    // MARK: - Report / Block menu

    @ViewBuilder
    private var moreMenu: some View {
        // Only meaningful when viewing someone else's profile that has a backing user.
        if let reportedUserId = profile.contactUserId {
            Menu {
                // Only for people actually saved in your contacts.
                if contactsVM.contactExists(contactUserId: reportedUserId) {
                    Button(role: .destructive) {
                        showRemoveConfirm = true
                    } label: {
                        Label("Remove Contact", systemImage: "person.crop.circle.badge.minus")
                    }
                    Divider()
                }
                Button(role: .destructive) {
                    showReport = true
                } label: {
                    Label("Report Profile", systemImage: "flag")
                }
                Button(role: .destructive) {
                    showBlockConfirm = true
                } label: {
                    Label("Block \(profile.name)", systemImage: "hand.raised")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .glassEffect(.clear.interactive(), in: Circle())
            }
            .sheet(isPresented: $showReport) {
                ReportContentView(reportedUserId: reportedUserId, reportedName: profile.name)
            }
            .alert("Block \(profile.name)?", isPresented: $showBlockConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Block", role: .destructive) {
                    blockUser(reportedUserId)
                }
            } message: {
                Text("They'll be removed from your Discover feed and our team will be notified to review their profile. You can unblock them anytime in Settings.")
            }
            .alert("Remove \(profile.name)?", isPresented: $showRemoveConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    removeContact(reportedUserId)
                }
            } message: {
                Text("You'll be removed from each other's contacts. Your interactions with them are kept, and you can connect again anytime.")
            }
        }
    }

    /// Same as Disconnect on the "Connected" pill: drops the connection both
    /// ways (disconnect_contact.sql), then leaves the profile.
    private func removeContact(_ contactUserId: UUID) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            await contactRequestVM.disconnect(from: contactUserId)
            await contactsVM.refresh()
        }
        dismiss()
    }

    private func blockUser(_ reportedUserId: UUID) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Hide instantly on-device…
        blockStore.block(id: reportedUserId, name: profile.name)
        // …and notify the developer via a moderation report.
        if let reporterId = authVM.currentUser?.id {
            Task {
                try? await ModerationService().submitReport(
                    reporterId: reporterId,
                    reportedUserId: reportedUserId,
                    reason: .blocked,
                    details: nil
                )
            }
        }
        dismiss()
    }

    // MARK: - Connect Request

    private enum ConnectState {
        case connect, pending, connected
    }

    private var connectState: ConnectState {
        guard let contactUserId = profile.contactUserId else { return .connect }
        if contactsVM.contactExists(contactUserId: contactUserId) { return .connected }
        switch contactRequestVM.sentStatuses[contactUserId] {
        case .pending:          return .pending
        case .accepted:         return .connected
        case .rejected, nil:    return .connect
        }
    }

    @ViewBuilder
    private var connectButton: some View {
        let state = connectState
        Button {
            guard let contactUserId = profile.contactUserId else { return }
            if state == .pending {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showWithdrawRequestConfirm = true
                return
            }
            guard state == .connect else { return }
            isSendingRequest = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                await contactRequestVM.sendRequest(to: contactUserId)
                isSendingRequest = false
            }
        } label: {
            HStack(spacing: 5) {
                if isSendingRequest {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.75)
                } else {
                    if let iconName = connectIconName(state) {
                        Image(systemName: iconName)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(connectLabel(state))
                        .font(.gilroy(.semiBold, size: 13))
                }
            }
            .foregroundStyle(connectForeground(state))
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(connectBackground(state), in: Capsule())
            .glassEffect(.clear.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(state == .connected || isSendingRequest)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: connectState)
        .confirmationDialog(
            "Withdraw connect request?",
            isPresented: $showWithdrawRequestConfirm,
            titleVisibility: .visible
        ) {
            Button("Withdraw Request", role: .destructive) {
                guard let contactUserId = profile.contactUserId else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await contactRequestVM.withdrawRequest(to: contactUserId) }
            }
            Button("Keep Request", role: .cancel) {}
        }
    }

    private func connectIconName(_ state: ConnectState) -> String? {
        switch state {
        case .connect:   return "link.badge.plus"
        case .pending:   return "clock.fill"
        case .connected: return nil
        }
    }

    private func connectLabel(_ state: ConnectState) -> String {
        switch state {
        case .connect:   return "Connect"
        case .pending:   return "Pending"
        case .connected: return "Connected"
        }
    }

    private func connectForeground(_ state: ConnectState) -> Color {
        switch state {
        case .connect:   return .white
        case .pending:   return .white.opacity(0.6)
        case .connected: return .white
        }
    }

    private func connectBackground(_ state: ConnectState) -> Color {
        switch state {
        case .connect:   return Color.white.opacity(0.12)
        case .pending:   return Color.white.opacity(0.06)
        case .connected: return Color.white.opacity(0.12)
        }
    }

    // MARK: - Share QR

    private var shareNavButton: some View {
        Button {
            if subscription.isPro, let shareUIImage {
                ShareSheet.present(
                    image: shareUIImage,
                    title: "\(profileVM.profile.fullName) · SuperDex"
                )
            } else {
                showPaywall = true
            }
        } label: {
            shareNavIcon
        }
    }

    private var shareNavIcon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .glassEffect(.clear.interactive(), in: Circle())
    }

    /// Changes whenever any field shown on the share card changes, so the
    /// rendered image stays in sync with edits (used as the render task's id).
    private var shareCardSignature: String {
        let p = profileVM.profile
        return [
            p.firstName, p.lastName, p.jobRole, p.companyName,
            "\(p.themeIndex)", p.username, p.qrCodeData
        ].joined(separator: "|")
    }

    private var shareQRImage: UIImage? {
        let p = profileVM.profile
        if let data = Data(base64Encoded: p.qrCodeData), !p.qrCodeData.isEmpty {
            return UIImage(data: data)
        }
        guard !p.username.isEmpty else { return nil }
        return QRCodeViewModel().generateQRCode(username: p.username)
    }

    @MainActor
    private func renderShareImage() {
        guard let qr = shareQRImage else { return }
        let p = profileVM.profile
        let card = QRShareCard(
            name: p.fullName,
            jobRole: p.jobRole,
            companyName: p.companyName,
            theme: p.theme,
            qrImage: qr
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        shareUIImage = renderer.uiImage
    }

    // MARK: - Profile Tab

    private var profileTabContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                heroCard
                    .padding(.top, 56)

                identitySection

                if showsInteractions {
                    interactionsSection
                }

                if !profile.bio.isEmpty {
                    aboutSection
                }

                if !profile.phone.isEmpty || !profile.email.isEmpty {
                    contactSection
                }

                if hasBusinessContact {
                    businessSection
                }

                if !activeLinks.isEmpty {
                    linksSection
                }

                if profile.isPremiumUser && !profile.portfolioImages.isEmpty {
                    portfolioSection
                }

                if !isUserProfile && !groupsContainingProfile.isEmpty {
                    groupsSection
                }

                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 20)
            .background(alignment: .top) {
                cardGlow
            }
        }
    }

    // MARK: - Hero Card

    @Environment(UserProfileViewModel.self) private var profileVM

    private var heroCard: some View {
        ProfileCardView(
            profile: profile,
            username: isUserProfile ? profileVM.profile.username : nil,
            allowsFlip: true
        )
        .aspectRatio(300.0 / 460.0, contentMode: .fit)
        .padding(.horizontal, 24)
        .shadow(color: accent.opacity(0.55), radius: 40, y: 18)
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(profile.name)
                    .font(.gilroy(.bold, size: 28))
                    .foregroundStyle(.white)

                if profile.isPremiumUser {
                    ProBadge(height: 20)
                }
            }

            if !profile.jobRole.isEmpty || !profile.companyName.isEmpty {
                Text(roleLine)
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var roleLine: String {
        switch (profile.jobRole.isEmpty, profile.companyName.isEmpty) {
        case (false, false): return "\(profile.jobRole) - \(profile.companyName)"
        case (false, true):  return profile.jobRole
        case (true, false):  return profile.companyName
        default:             return ""
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Contact", count: nil)

            VStack(spacing: 8) {
                if !profile.phone.isEmpty {
                    contactRow(icon: "phone.fill", label: "Phone", value: profile.phone) {
                        if let url = URL(string: "tel:\(profile.phone.filter { $0.isNumber || $0 == "+" })") {
                            openURL(url)
                        }
                    }
                }
                if !profile.email.isEmpty {
                    contactRow(icon: "envelope.fill", label: "Email", value: profile.email) {
                        if let url = URL(string: "mailto:\(profile.email)") {
                            openURL(url)
                        }
                    }
                }
            }
        }
    }

    /// `brandIcon` (a BrandIcon name, e.g. "whatsapp") replaces the SF Symbol
    /// so rows match the brand glyphs used for links.
    private func contactRow(
        icon: String,
        brandIcon: String? = nil,
        label: String,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.15))
                    if let brandIcon {
                        BrandIcon(name: brandIcon)
                            .foregroundStyle(accent)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.gilroy(.semiBold, size: 11))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .tracking(0.8)
                        .textCase(.uppercase)
                    Text(value)
                        .font(.gilroy(.medium, size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.25))
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
        .buttonStyle(.plain)
    }

    // MARK: - Business

    private var hasBusinessContact: Bool {
        !profile.businessPhone.isEmpty || !profile.businessWhatsapp.isEmpty || !profile.businessEmail.isEmpty
    }

    /// Business phone / WhatsApp / email from Edit Profile → Business Contact.
    private var businessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Business", count: nil)

            VStack(spacing: 8) {
                if !profile.businessPhone.isEmpty {
                    let number = "\(profile.businessCountryCode)\(profile.businessPhone)"
                    contactRow(
                        icon: "phone.fill",
                        label: "Business Phone",
                        value: displayNumber(code: profile.businessCountryCode, number: profile.businessPhone)
                    ) {
                        if let url = URL(string: "tel:\(number.filter { $0.isNumber || $0 == "+" })") {
                            openURL(url)
                        }
                    }
                }
                if !profile.businessWhatsapp.isEmpty {
                    contactRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        brandIcon: ProfileLink.whatsapp.brandIconName,
                        label: "Business WhatsApp",
                        value: displayNumber(code: profile.businessWhatsappCountryCode, number: profile.businessWhatsapp)
                    ) {
                        let digits = "\(profile.businessWhatsappCountryCode)\(profile.businessWhatsapp)".filter(\.isNumber)
                        if let url = URL(string: "https://wa.me/\(digits)") {
                            openURL(url)
                        }
                    }
                }
                if !profile.businessEmail.isEmpty {
                    contactRow(icon: "envelope.fill", label: "Business Email", value: profile.businessEmail) {
                        if let url = URL(string: "mailto:\(profile.businessEmail)") {
                            openURL(url)
                        }
                    }
                }
            }
        }
    }

    private func displayNumber(code: String, number: String) -> String {
        code.isEmpty ? number : "\(code) \(number)"
    }

    // MARK: - Links

    private var activeLinks: [ProfileLinkEntry] {
        ProfileLink.allCases.compactMap { link in
            guard let value = profile.links[link.rawValue], !value.isEmpty else { return nil }
            return ProfileLinkEntry(
                link: link,
                value: value,
                customLabel: link == .customLink ? profile.customLinkTitle : ""
            )
        }
    }

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Links", count: "\(activeLinks.count)")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(activeLinks, id: \.self) { entry in
                    linkCard(entry: entry)
                }
            }
        }
    }

    private func linkCard(entry: ProfileLinkEntry) -> some View {
        Button {
            if let url = entry.url {
                openURL(url)
            }
        } label: {
            HStack(spacing: 10) {
                linkIcon(for: entry.link)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.label)
                        .font(.gilroy(.semiBold, size: 13))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.value)
                        .font(.gilroy(.medium, size: 11))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func linkIcon(for link: ProfileLink) -> some View {
        if let brandName = link.brandIconName {
            BrandIcon(name: brandName)
                .foregroundStyle(accent)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: link.fallbackSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "About", count: nil)

            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accent, accentSecondary.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .clipShape(Capsule())

                Text(profile.bio)
                    .font(.gilroy(.medium, size: 15))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Portfolio

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Portfolio", count: "\(profile.portfolioImages.count)")

            PortfolioMasonryGrid(
                images: profile.portfolioImages,
                accent: accent,
                onTap: { index in
                    selectedImageIndex = index
                }
            )
        }
    }

    // MARK: - Groups

    private var groupsContainingProfile: [CardGroup] {
        home.groups.filter { group in
            group.members.contains { matches(member: $0) }
        }
    }

    private func matches(member: GroupMember) -> Bool {
        // If both sides have a userId, that answer is final.
        if let memberUserId = member.userId, let profileUserId = profile.contactUserId {
            return memberUserId == profileUserId
        }
        // Fall back to email only when at least one side lacks a userId.
        let memberEmail = member.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let profileEmail = profile.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !memberEmail.isEmpty && memberEmail == profileEmail
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Decks", count: "\(groupsContainingProfile.count)")

            VStack(spacing: 8) {
                ForEach(groupsContainingProfile) { group in
                    groupRow(group)
                }
            }
        }
    }

    private func groupRow(_ group: CardGroup) -> some View {
        HStack(spacing: 14) {
            groupBadge(for: group)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.gilroy(.semiBold, size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(group.members.count) member\(group.members.count == 1 ? "" : "s")")
                    .font(.gilroy(.medium, size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()
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
    private func groupBadge(for group: CardGroup) -> some View {
        if let data = group.wallpaperData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.opacity(0.18))
                Image(systemName: group.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
    }

    // MARK: - Interactions

    /// Interactions are private notes about a saved connection, so they only make
    /// sense on someone else's profile that's in your contacts.
    private var showsInteractions: Bool {
        !isUserProfile && !isDiscovery && profile.contactUserId != nil
    }

    private var firstName: String {
        profile.name.split(separator: " ").first.map(String.init) ?? profile.name
    }

    private var latestMeeting: EventMeeting? {
        meetings.max(by: { $0.date < $1.date })
    }

    private var interactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("How you know \(firstName)")
                    .font(.gilroy(.bold, size: 18))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                if !meetings.isEmpty {
                    Button {
                        showActivity = true
                    } label: {
                        HStack(spacing: 3) {
                            Text(meetings.count > 1 ? "See all \(meetings.count)" : "See all")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .font(.gilroy(.semiBold, size: 14))
                        .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let latestMeeting {
                Button {
                    showActivity = true
                } label: {
                    MeetingCard(meeting: latestMeeting, accent: accent)
                }
                .buttonStyle(.plain)

                if meetings.count > 1 {
                    HStack(spacing: 10) {
                        StatPill(value: "\(meetings.count)", label: "Interactions")
                        StatPill(value: firstMetText, label: "First met")
                        StatPill(value: lastMetText, label: "Last met")
                    }
                }

                addAnotherInteractionRow
            } else {
                emptyInteractionsCard
            }
        }
    }

    private func openAddInteraction(voice: Bool) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        addInteractionByVoice = voice
        showAddInteraction = true
    }

    /// Compact row under existing interactions: speak (primary) or type.
    private var addAnotherInteractionRow: some View {
        HStack(spacing: 10) {
            Button {
                openAddInteraction(voice: true)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Record another interaction")
                        .font(.gilroy(.semiBold, size: 15))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().fill(accent.opacity(0.18)))
                .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                openAddInteraction(voice: false)
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Type an interaction")
        }
    }

    private var emptyInteractionsCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("Where did you meet \(firstName)?")
                    .font(.gilroy(.bold, size: 17))
                    .foregroundStyle(.white)
                Text("Just say it — where you met and what you talked about. We'll write it down.")
                    .font(.gilroy(.medium, size: 13))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineSpacing(2)
            }
            .multilineTextAlignment(.center)

            Button {
                openAddInteraction(voice: true)
            } label: {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.14))
                        .frame(width: 96, height: 96)
                    Circle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(accent)
                        .frame(width: 64, height: 64)
                        .shadow(color: accent.opacity(0.55), radius: 16, y: 6)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(isOnyx ? .black : .white)
                }
            }
            .buttonStyle(GroupCardPressStyle())
            .accessibilityLabel("Record an interaction with \(firstName)")

            HStack(spacing: 6) {
                Text("Tap to speak")
                    .foregroundStyle(Color.white.opacity(0.5))
                Text("·")
                    .foregroundStyle(Color.white.opacity(0.3))
                Button("Type instead") {
                    openAddInteraction(voice: false)
                }
                .foregroundStyle(accent)
            }
            .font(.gilroy(.semiBold, size: 13))
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.14), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, count: String?) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white)

            if let count {
                Text(count)
                    .font(.gilroy(.semiBold, size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color.white.opacity(0.08))
                    )
            }

            Spacer()
        }
    }

    private var firstMetText: String {
        guard let date = meetings.map(\.date).min() else { return "—" }
        return monthDayFormatter.string(from: date)
    }

    private var lastMetText: String {
        guard let date = meetings.map(\.date).max() else { return "—" }
        return monthDayFormatter.string(from: date)
    }

    private var monthDayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }
}

// MARK: - Edit Profile Sheet

private struct EditProfileSheet: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel
        EditProfileView(profile: $viewModel.profile, onSave: {
            viewModel.saveProfileImmediately()
            dismiss()
        }, userId: viewModel.currentUserId)
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label.uppercased())
                .font(.gilroy(.semiBold, size: 9))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Portfolio Viewer Index (for fullScreenCover binding)

private struct PortfolioViewerIndex: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Pinterest-style Masonry Grid

private struct PortfolioMasonryGrid: View {
    let images: [PortfolioImage]
    let accent: Color
    let onTap: (Int) -> Void

    @State private var imageHeights: [String: CGFloat] = [:]

    private var leftColumn: [(Int, PortfolioImage)] {
        var items: [(Int, PortfolioImage)] = []
        var leftH: CGFloat = 0
        var rightH: CGFloat = 0
        for (i, img) in images.enumerated() {
            let h = imageHeights[img.id] ?? 200
            if leftH <= rightH {
                items.append((i, img))
                leftH += h + 10
            } else {
                rightH += h + 10
            }
        }
        return items
    }

    private var rightColumn: [(Int, PortfolioImage)] {
        var items: [(Int, PortfolioImage)] = []
        var leftH: CGFloat = 0
        var rightH: CGFloat = 0
        for (i, img) in images.enumerated() {
            let h = imageHeights[img.id] ?? 200
            if leftH <= rightH {
                leftH += h + 10
            } else {
                items.append((i, img))
                rightH += h + 10
            }
        }
        return items
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                ForEach(leftColumn, id: \.1.id) { index, item in
                    masonryCell(item: item, index: index)
                }
            }
            VStack(spacing: 10) {
                ForEach(rightColumn, id: \.1.id) { index, item in
                    masonryCell(item: item, index: index)
                }
            }
        }
    }

    private func masonryCell(item: PortfolioImage, index: Int) -> some View {
        Button { onTap(index) } label: {
            ZStack(alignment: .bottomTrailing) {
                if let url = URL(string: item.imageURL), !item.imageURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: ImageHeightKey.self,
                                            value: [item.id: geo.size.height]
                                        )
                                    }
                                )
                        case .failure:
                            placeholderView
                        default:
                            ZStack {
                                Color.white.opacity(0.04)
                                ProgressView().tint(.white.opacity(0.5))
                            }
                            .frame(height: 200)
                        }
                    }
                } else {
                    placeholderView
                }

                if !item.linkURL.isEmpty {
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onPreferenceChange(ImageHeightKey.self) { heights in
            imageHeights.merge(heights) { _, new in new }
        }
    }

    private var placeholderView: some View {
        ZStack {
            Color.white.opacity(0.04)
            Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.2))
        }
        .frame(height: 200)
    }
}

private struct ImageHeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Fullscreen Portfolio Viewer

private struct PortfolioViewer: View {
    let images: [PortfolioImage]
    let currentIndex: Int
    let onDismiss: () -> Void
    let onOpenLink: (URL) -> Void

    @State private var index: Int
    @GestureState private var dragOffset: CGFloat = 0

    init(images: [PortfolioImage], currentIndex: Int, onDismiss: @escaping () -> Void, onOpenLink: @escaping (URL) -> Void) {
        self.images = images
        self.currentIndex = currentIndex
        self.onDismiss = onDismiss
        self.onOpenLink = onOpenLink
        self._index = State(initialValue: currentIndex)
    }

    private var currentImage: PortfolioImage { images[index] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(images.enumerated()), id: \.element.id) { i, item in
                    ZStack {
                        if let url = URL(string: item.imageURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .padding(.horizontal, 4)
                                default:
                                    ProgressView().tint(.white)
                                }
                            }
                        }
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .ignoresSafeArea()

            VStack {
                topControls
                Spacer()
                bottomControls
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private var topControls: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            Text("\(index + 1) / \(images.count)")
                .font(.gilroy(.semiBold, size: 14))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            if !currentImage.linkURL.isEmpty, let url = URL(string: currentImage.linkURL) {
                Button { onOpenLink(url) } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                }
            } else {
                Color.clear.frame(width: 38, height: 38)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var bottomControls: some View {
        HStack(spacing: 24) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    index = max(0, index - 1)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(index > 0 ? .white : .white.opacity(0.25))
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(index == 0)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    index = min(images.count - 1, index + 1)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(index < images.count - 1 ? .white : .white.opacity(0.25))
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(index == images.count - 1)
        }
        .padding(.bottom, 40)
    }
}

#Preview {
    NavigationStack {
        ProfileDetailView(
            profile: ProfileCard(
                firstName: "Ben",
                companyName: "Apple",
                jobRole: "iOS Developer",
                bio: "Building delightful apps one pixel at a time.",
                phone: "+1 (555) 100-2001",
                email: "ben@example.com",
                links: ["instagram": "@ben.dev", "linkedin": "linkedin.com/in/ben", "x": "@ben_dev", "github": "github.com/ben"],
                theme: .glacier
            )
        )
    }
    .environment(AuthViewModel())
    .environment(HomeViewModel())
    .environment(UserProfileViewModel())
    .environment(SubscriptionManager())
    .environment(BlockStore())
}
