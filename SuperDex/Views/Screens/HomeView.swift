//
//  HomeView.swift
//  HomeScreen
//

import SwiftUI
import Auth

struct HomeView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(UserProfileViewModel.self) private var profileVM
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(DiscoverViewModel.self) private var discoverVM
    @Environment(ContactRequestViewModel.self) private var requestVM
    @Environment(NotificationsViewModel.self) private var notificationsVM
    @Environment(\.openScanner) private var openScanner

    @Environment(EventsViewModel.self) private var eventsVM
    @State private var showQRSheet = false
    @State private var showViewersSheet = false
    @State private var showEditProfile = false
    @State private var showsDeckInfo = false
    /// Pops the My Card tile when the onboarding card genies into it.
    @State private var myCardPop = false
    /// The My Card tile on screen, so the onboarding card can land on it.
    @State private var myCardFrame: CGRect = .zero
    @State private var showsCardLanding = false
    /// Arriving from onboarding, Home's sections start hidden and rise in
    /// one by one (homeEntranceItem); this flips once it's on screen.
    @State private var entranceSettled = false
    /// The tab bar slides up after the sections.
    @State private var tabBarRevealed = false

    private var sectionsArrived: Bool { !profileVM.celebrateMyCard || entranceSettled }
    private var tabBarArrived: Bool { !profileVM.celebrateMyCard || tabBarRevealed }

    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(AuthViewModel.self) private var authVM
    @State private var latestDiscussions: [UUID: EventMeeting] = [:]
    @State private var selectedConnection: Contact?
    @State private var discussionTarget: Contact?
    @State private var discussionByVoice = false
    private let meetingService = MeetingService()

    @Namespace private var profileNamespace
    private var userProfile: UserProfileData { profileVM.profile }

    private enum HomeRoute: Hashable { case allEvents, allGroups }

    /// Filters for "Upcoming events near you", persisted on device.
    /// Empty string means "all".
    // Event filters live on the shared EventsViewModel, so a selection
    // made here (e.g. Bengaluru + Luma) is what the Events page opens
    // with, and vice versa.

    private let accentIndigo = Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0)

    private var isSearching: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        return NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .homeEntranceItem(order: 0, arrived: sectionsArrived)

                        quickActions
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .homeEntranceItem(order: 1, arrived: sectionsArrived)

                        if !isProfileComplete {
                            ProfileCompletionCard(profile: userProfile) {
                                showEditProfile = true
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .homeEntranceItem(order: 2, arrived: sectionsArrived)
                        }

                        // Search hidden for now — recent connections is the hero.
                        // searchBar
                        //     .padding(.horizontal, 16)
                        //     .padding(.top, 20)
                        //
                        // if isSearching {
                        //     if viewModel.filteredGroups.isEmpty {
                        //         VStack { Spacer(minLength: 80); noResultsState; Spacer(minLength: 80) }
                        //     } else {
                        //         searchResultsList
                        //     }
                        // }

                        VStack(alignment: .leading, spacing: 36) {
                            recentConnectionsSection
                                .homeEntranceItem(order: 3, arrived: sectionsArrived)
                            eventsSection
                                .homeEntranceItem(order: 4, arrived: sectionsArrived)
                            groupsSection
                                .padding(.horizontal, 20)
                                .homeEntranceItem(order: 5, arrived: sectionsArrived)
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 120)
                    }
                }
                .scrollIndicators(.hidden)
                .reportsTopScroll()

            }
            .background(AppBackground())
            .navigationBarHidden(true)
            .toolbarVisibility(tabBarArrived ? .visible : .hidden, for: .tabBar)
            .task {
                guard profileVM.celebrateMyCard, !entranceSettled else { return }
                // Let the first (heavy) frame land on the black background,
                // then build Home up section by section…
                try? await Task.sleep(for: .milliseconds(120))
                entranceSettled = true
                // …and bring the tab bar up as the last sections arrive.
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { tabBarRevealed = true }
            }
            .overlay {
                if showsCardLanding {
                    MyCardLandingOverlay(
                        profile: userProfile.asProfileCard,
                        target: myCardFrame
                    ) {
                        Task { await popMyCardTile() }
                    }
                }
            }
            .task {
                await eventsVM.loadIfNeeded()
            }
            .task(id: recentConnections.map(\.id)) {
                await loadLatestDiscussions()
            }
            .onAppear {
                // Discussions may have been edited on a profile screen.
                Task { await loadLatestDiscussions() }
            }
            .sheet(item: $discussionTarget) { contact in
                AddMeetingView(personName: contact.name, startsWithVoice: discussionByVoice) { meeting in
                    Task { await saveDiscussion(meeting, for: contact) }
                }
            }
            .task {
                // Keep the Requests badge / viewers list fresh on Home.
                await requestVM.refresh()
                await discoverVM.loadViewers()
            }
            .sheet(isPresented: $showQRSheet) {
                // Card page first, then the QR grows to full size, ready to scan.
                ProfileQRSheet(
                    profile: userProfile.asProfileCard,
                    username: userProfile.username,
                    qrCodeData: userProfile.qrCodeData,
                    magnifiesOnOpen: true
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showViewersSheet) {
                ProfileViewersSheet()
            }
            .sheet(isPresented: $showsDeckInfo) {
                DeckInfoSheet()
            }
            .sheet(isPresented: $showEditProfile) {
                HomeEditProfileSheet()
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .allEvents:
                    EventsScreen(viewModel: eventsVM, showsBackButton: true)
                case .allGroups:
                    GroupsView()
                }
            }
            .navigationDestination(for: AppEvent.self) { event in
                EventDetailView(event: event)
            }
            .navigationDestination(for: CardGroup.self) { group in
                GroupDetailView(
                    group: group,
                    onEdit: { viewModel.groupBeingEdited = group }
                )
                .navigationTransition(.zoom(sourceID: group.id, in: profileNamespace))
            }
            .navigationDestination(item: $selectedConnection) { contact in
                ProfileDetailView(profile: contact.asProfileCard)
                    .navigationTransition(.zoom(sourceID: contact.id, in: profileNamespace))
            }
            .navigationDestination(item: $viewModel.selectedProfile) { profile in
                UserProfileView(profile: profile, isUserProfile: true)
                    .navigationTransition(.zoom(sourceID: "homeAvatar", in: profileNamespace))
            }
            .alert(
                "Delete Deck?",
                isPresented: Binding(
                    get: { viewModel.groupPendingDeletion != nil },
                    set: { if !$0 { viewModel.groupPendingDeletion = nil } }
                ),
                presenting: viewModel.groupPendingDeletion
            ) { group in
                Button("Delete", role: .destructive) {
                    viewModel.deleteGroup(id: group.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: { group in
                Text("\"\(group.name)\" will be permanently deleted. This cannot be undone.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Image((subscription.isPro || userProfile.hasPro) ? "SuperDexProText" : "SuperDexText")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)

                VStack(alignment: .leading, spacing: -4) {
                    Text("Hello")
                        .font(.gilroy(.bold, size: 42))
                        .foregroundStyle(.white)
                    Text("\(greetingName)!")
                        .font(.gilroy(.bold, size: 42))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                notificationsButton
                avatarButton
            }
            .padding(.top, 16)
        }
    }

    /// Shared size so the bell and avatar read as a matched pair.
    private let headerButtonSize: CGFloat = 48
    /// Content size inside the circle (bell glyph frame and memoji alike).
    private let headerIconSize: CGFloat = 30

    private var avatarButton: some View {
        Button {
            viewModel.selectedProfile = userProfile.asProfileCard
        } label: {
            headerGlassCircle {
                Image(userProfile.avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: headerIconSize, height: headerIconSize)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: "homeAvatar", in: profileNamespace)
        .accessibilityLabel("My profile")
    }

    /// Opens the in-app notifications feed; the badge counts unread ones.
    private var notificationsButton: some View {
        // Unread in-app notifications; falls back to pending connect
        // requests until the notifications feed has loaded.
        let unread = notificationsVM.hasLoaded ? notificationsVM.unreadCount : requestVM.pendingCount
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            notificationsVM.open()
        } label: {
            headerGlassCircle {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: headerIconSize, height: headerIconSize)
                    .symbolEffect(.wiggle, value: unread)
            }
            .overlay(alignment: .topTrailing) {
                if unread > 0 {
                    Text(unread > 9 ? "9+" : "\(unread)")
                        .font(.gilroy(.bold, size: 11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Capsule().fill(Color.red))
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.5), lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: unread)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unread > 0 ? "Notifications, \(unread) new" : "Notifications")
    }

    /// Identical glass circle for every header button, so the bell and the
    /// avatar share size, padding and material exactly.
    private func headerGlassCircle<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: headerButtonSize, height: headerButtonSize)
            .contentShape(Circle())
            .glassEffect(.clear.interactive(), in: Circle())
    }

    private var greetingName: String {
        let trimmed = userProfile.firstName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "there" : trimmed
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickActionTile(title: "My Card", icon: "person.text.rectangle") {
                showQRSheet = true
            }
            .scaleEffect(myCardPop ? 1.12 : 1)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(myCardPop ? 0.9 : 0), lineWidth: 2)
                    .scaleEffect(myCardPop ? 1.12 : 1)
            }
            .shadow(color: accentIndigo.opacity(myCardPop ? 0.8 : 0), radius: 18)
            .zIndex(1)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { myCardFrame = $0 }
            .task(id: profileVM.celebrateMyCard) {
                // Just finished onboarding: fly the card in and land it here.
                guard profileVM.celebrateMyCard else { return }
                try? await Task.sleep(for: .milliseconds(450))
                guard myCardFrame != .zero else { return }
                showsCardLanding = true
            }
            quickActionTile(title: "Profile Views", icon: "eye.fill") {
                showViewersSheet = true
            }
            quickActionTile(title: "Scan", icon: "qrcode.viewfinder") {
                openScanner()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    /// The card has genied into the tile — pop it so the eye lands there.
    private func popMyCardTile() async {
        showsCardLanding = false
        profileVM.celebrateMyCard = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { myCardPop = true }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { myCardPop = false }
    }

    private func quickActionTile(
        title: String,
        icon: String,
        badge: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(height: 26)

                Text(title)
                    .font(.gilroy(.semiBold, size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.gilroy(.bold, size: 11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Capsule().fill(Color.red))
                        .offset(x: -8, y: 8)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge > 0 ? "\(title), \(badge) pending" : title)
    }

    // MARK: - Search

    private var searchBar: some View {
        @Bindable var viewModel = viewModel
        return HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white.opacity(0.55))

            TextField("", text: $viewModel.searchText, prompt:
                Text("Search people, roles, events…")
                    .font(.gilroy(.regular, size: 15))
                    .foregroundColor(.white.opacity(0.45))
            )
            .font(.gilroy(.regular, size: 15))
            .foregroundStyle(.white)
            .tint(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
    }

    // MARK: - Recent connections (hero)

    /// Five most recently saved contacts, newest first. Contacts without a
    /// timestamp keep their fetch order (oldest → newest), so reverse it.
    private var recentConnections: [Contact] {
        let newestFirst = Array(contactsVM.contacts.reversed())
        let sorted = newestFirst.enumerated().sorted { lhs, rhs in
            switch (lhs.element.connectedAt, rhs.element.connectedAt) {
            case let (l?, r?): return l > r
            default: return lhs.offset < rhs.offset
            }
        }
        return Array(sorted.map(\.element).prefix(5))
    }

    private var newConnectionsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return contactsVM.contacts.filter { ($0.connectedAt ?? .distantPast) >= weekAgo }.count
    }

    private var connectionsSubtitle: String {
        let total = contactsVM.contacts.count
        var text = "\(total) connection\(total == 1 ? "" : "s")"
        if newConnectionsThisWeek > 0 {
            text += " · \(newConnectionsThisWeek) new this week"
        }
        return text
    }

    /// New users are nudged to make this many connections.
    private let connectionGoal = 5

    private var isProfileComplete: Bool {
        ProfileChecklistItem.allCases.allSatisfy { $0.isComplete(in: userProfile) }
    }

    private var recentConnectionsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent connections")
                    .font(.gilroy(.bold, size: 28))
                    .foregroundStyle(.white)
                Text(contactsVM.contacts.isEmpty ? "People you meet show up here" : connectionsSubtitle)
                    .font(.gilroy(.medium, size: 15))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 20)

            if contactsVM.contacts.count < connectionGoal {
                ConnectionGoalCard(count: contactsVM.contacts.count, goal: connectionGoal) {
                    openScanner()
                }
                .padding(.horizontal, 20)
            }

            if !contactsVM.contacts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(recentConnections) { contact in
                            connectionCard(contact)
                                .containerRelativeFrame(.horizontal) { width, _ in width * 0.72 }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .safeAreaPadding(.horizontal, 20)
                .scrollClipDisabled()
            }
        }
    }

    private let avatarSize: CGFloat = 88

    private func connectionCard(_ contact: Contact) -> some View {
        let discussion = latestDiscussions[contact.contactUserId]
        let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedConnection = contact
        } label: {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(contact.name)
                        .font(.gilroy(.bold, size: 20))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(roleLine(for: contact))
                        .font(.gilroy(.medium, size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.top, avatarSize / 2 + 18)

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                VStack(alignment: .leading, spacing: 8) {
                    if let discussion {
                        discussionPreview(discussion)
                    } else {
                        addDiscussionButton(for: contact)

                        Text(connectedText(for: contact))
                            .font(.gilroy(.medium, size: 13))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)

                Spacer(minLength: 18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .background(
                cardShape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(cardShape.strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    discussionByVoice = false
                    discussionTarget = contact
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityLabel("Add what you discussed with \(contact.name)")
            }
            .overlay(alignment: .top) {
                connectionAvatar(contact)
                    .offset(y: -avatarSize / 2)
            }
            .padding(.top, avatarSize / 2)
            .contentShape(cardShape)
        }
        .buttonStyle(GroupCardPressStyle())
        .matchedTransitionSource(id: contact.id, in: profileNamespace)
    }

    private func connectionAvatar(_ contact: Contact) -> some View {
        let colors = contact.theme.gradientColors
        return Image(contact.avatar)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .padding(10)
            .frame(width: avatarSize, height: avatarSize)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: colors.isEmpty ? [.indigo, .purple] : colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.black.opacity(0.6), lineWidth: 4))
            .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
    }

    /// "Met at <place> · <when>" followed by a quoted "You talked about" note,
    /// so the card reads as a record of your interaction rather than a bare label.
    private func discussionPreview(_ meeting: EventMeeting) -> some View {
        let notes = meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accentIndigo)
                Group {
                    if let place = meeting.placeName {
                        Text("\(Text("Met at ").foregroundStyle(.white.opacity(0.55)))\(Text(place).foregroundStyle(.white))")
                    } else {
                        Text("Met").foregroundStyle(.white.opacity(0.55))
                    }
                }
                .font(.gilroy(.semiBold, size: 14))
                .lineLimit(1)
                Text(meeting.placeName == nil ? meeting.date.interactionAgoText : "· \(meeting.date.interactionAgoText)")
                    .font(.gilroy(.medium, size: 13))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            HStack(alignment: .top, spacing: 10) {
                Capsule()
                    .fill(accentIndigo.opacity(0.8))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text("YOU TALKED ABOUT")
                        .font(.gilroy(.semiBold, size: 10))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.4))
                    Text(notes.isEmpty ? "Tap ✎ to add what you discussed" : notes)
                        .font(.gilroy(notes.isEmpty ? .regular : .medium, size: 14))
                        .foregroundStyle(.white.opacity(notes.isEmpty ? 0.45 : 0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func addDiscussionButton(for contact: Contact) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            discussionByVoice = true
            discussionTarget = contact
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(accentIndigo))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Record an interaction")
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(accentIndigo)
                    Text("Where you met & what you talked about")
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }

    private func roleLine(for contact: Contact) -> String {
        [contact.jobRole, contact.companyName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func connectedText(for contact: Contact) -> String {
        guard let date = contact.connectedAt else { return "Connected" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Connected today" }
        if calendar.isDateInYesterday(date) { return "Connected yesterday" }
        let sameYear = calendar.isDate(date, equalTo: .now, toGranularity: .year)
        return "Connected " + date.formatted(sameYear ? .dateTime.day().month(.abbreviated)
                                                      : .dateTime.day().month(.abbreviated).year())
    }

    private func loadLatestDiscussions() async {
        guard let userId = authVM.currentUser?.id else { return }
        let ids = recentConnections.map(\.contactUserId)
        do {
            latestDiscussions = try await meetingService.fetchLatest(userId: userId, contactUserIds: ids)
        } catch {
            print("Failed to load discussions: \(error.localizedDescription)")
        }
    }

    private func saveDiscussion(_ meeting: EventMeeting, for contact: Contact) async {
        guard let userId = authVM.currentUser?.id else { return }
        do {
            try await meetingService.insert(meeting, userId: userId, contactUserId: contact.contactUserId)
            if let current = latestDiscussions[contact.contactUserId], current.date > meeting.date { return }
            latestDiscussions[contact.contactUserId] = meeting
        } catch {
            print("Failed to save discussion: \(error.localizedDescription)")
        }
    }

    // MARK: - Upcoming events

    private var eventsSection: some View {
        UpcomingEventsSection(viewModel: eventsVM, allEventsRoute: HomeRoute.allEvents)
    }

    // MARK: - Your groups

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Your decks",
                route: viewModel.groups.isEmpty ? nil : .allGroups,
                onInfo: { showsDeckInfo = true }
            )

            if viewModel.groups.isEmpty {
                createGroupPrompt
            } else {
                VStack(spacing: 14) {
                    ForEach(Array(viewModel.groups.prefix(3))) { group in
                        SwipeActionRow(
                            accent: group.color,
                            onEdit: { viewModel.groupBeingEdited = group },
                            onDelete: { viewModel.groupPendingDeletion = group }
                        ) {
                            NavigationLink(value: group) {
                                GroupCardView(group: group)
                            }
                            .matchedTransitionSource(id: group.id, in: profileNamespace)
                            .buttonStyle(GroupCardPressStyle())
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, route: HomeRoute?, onInfo: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .center, spacing: 4) {
                Text(title)
                    .font(.gilroy(.bold, size: 20))
                    .foregroundStyle(.white)

                if let onInfo {
                    DeckInfoButton(size: 16, action: onInfo)
                        .frame(height: 20)
                }
            }

            Spacer()

            if let route {
                NavigationLink(value: route) {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.gilroy(.semiBold, size: 13))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var createGroupPrompt: some View {
        Button {
            viewModel.prepareNewGroup()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.25))
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.indigo)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create your first deck")
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white)
                    Text("Organize the people you meet into decks.")
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(GroupCardPressStyle())
    }

    // MARK: - Search results

    private var searchResultsList: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.filteredGroups) { group in
                SwipeActionRow(
                    accent: group.color,
                    onEdit: { viewModel.groupBeingEdited = group },
                    onDelete: { viewModel.groupPendingDeletion = group }
                ) {
                    NavigationLink(value: group) {
                        GroupCardView(group: group)
                    }
                    .matchedTransitionSource(id: group.id, in: profileNamespace)
                    .buttonStyle(GroupCardPressStyle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 120)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            Image("empty")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140)
                .opacity(0.9)

            emptyStateText
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 300)
                .padding(.horizontal, 32)
        }
    }

    private var emptyStateText: Text {
        Text("No deck added yet, use ")
        + Text(Image(systemName: "plus.circle.fill")).foregroundColor(.blue)
        + Text(" button to create\na new deck with people")
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.gilroy(.regular, size: 32))
                .foregroundStyle(.white.opacity(0.45))

            Text("No decks match \u{201C}\(viewModel.searchText)\u{201D}")
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.horizontal, 32)
        }
    }

}

// MARK: - Font helper

extension Font {
    enum GilroyWeight: String {
        case light = "Gilroy-Light"
        case regular = "Gilroy-Regular"
        case medium = "Gilroy-Medium"
        case semiBold = "Gilroy-SemiBold"
        case bold = "Gilroy-Bold"
        case extraBold = "Gilroy-ExtraBold"

        var systemWeight: Font.Weight {
            switch self {
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semiBold: return .semibold
            case .bold: return .bold
            case .extraBold: return .heavy
            }
        }

        var fontNameFallbacks: [String] {
            switch self {
            case .light: return ["Gilroy-Light"]
            case .regular: return ["Gilroy-Regular"]
            case .medium: return ["Gilroy-Medium", "Gilroy-Regular"]
            case .semiBold: return ["Gilroy-SemiBold", "Gilroy-Bold", "Gilroy-Medium"]
            case .bold: return ["Gilroy-Bold"]
            case .extraBold: return ["Gilroy-ExtraBold", "Gilroy-Heavy", "Gilroy-Bold"]
            }
        }
    }

    static func gilroy(_ weight: GilroyWeight, size: CGFloat) -> Font {
        for name in weight.fontNameFallbacks where UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight.systemWeight, design: .rounded)
    }
}

#Preview {
    HomeView()
        .environment(UserProfileViewModel())
        .environment(HomeViewModel())
        .environment(SubscriptionManager())
        .environment(EventsViewModel())
        .environment(NotificationsViewModel())
        .preferredColorScheme(.dark)
}

// MARK: - Edit profile sheet

/// Edits a draft so cancelling the sheet leaves the saved profile untouched.
private struct HomeEditProfileSheet: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = UserProfileData()

    var body: some View {
        EditProfileView(profile: $draft, onSave: {
            viewModel.profile = draft
            viewModel.saveProfileImmediately()
            dismiss()
        }, userId: viewModel.currentUserId)
        .onAppear {
            draft = viewModel.profile
        }
    }
}
