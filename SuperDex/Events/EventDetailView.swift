//
//  EventDetailView.swift
//  SuperDex
//
//  Full-screen event page, styled to match GroupDetailView, with a
//  button to register on the website the event is listed on.
//

import SwiftUI

struct EventDetailView: View {
    let event: AppEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(HomeViewModel.self) private var home
    @Environment(ContactRequestViewModel.self) private var requestVM
    @Environment(ContactsViewModel.self) private var contactsVM

    @State private var loadedDescription: String?
    @State private var isLoadingDescription = false
    @State private var isDescriptionExpanded = false
    /// Set when the user leaves for the registration site; when the
    /// app becomes active again we ask whether they registered.
    @State private var awaitingReturnFromRegistration = false
    @State private var showDidRegisterPrompt = false
    @State private var showGroupCreatedAlert = false
    @State private var createdGroupExisted = false
    @State private var showCancelRegistrationPrompt = false
    @State private var linkCopied = false
    /// The event's group, looked up after creation so the alert's
    /// "Go to group" button can push straight into it.
    @State private var groupToOpen: CardGroup?
    /// SuperDex users who marked themselves registered for this event.
    @State private var attendees: [EventAttendee] = []
    @State private var isLoadingAttendees = false
    @State private var showAllAttendees = false

    private let registrationService = EventRegistrationService()
    private var registeredStore: RegisteredEventsStore { .shared }
    private var isRegistered: Bool { registeredStore.isRegistered(event.id) }

    /// The group named after this event, if it exists.
    private var eventGroup: CardGroup? {
        let name = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return home.groups.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private var accent: Color { event.source.brandColor }

    /// Listing pages don't carry descriptions; fall back to the one
    /// fetched from the event's own page.
    private var resolvedDescription: String? {
        event.descriptionText ?? loadedDescription
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Color.clear.frame(height: 56)

                    heroCard
                        .padding(.horizontal, 20)

                    titleSection
                        .padding(.horizontal, 22)

                    attendeesSection
                        .padding(.horizontal, 22)

                    registerSection
                        .padding(.horizontal, 22)
                        .padding(.top, 4)
                        .padding(.bottom, 56)
                }
                .frame(maxWidth: .infinity)
            }

            topBar
                .padding(.horizontal, 20)
                .padding(.top, 4)
        }
        .background {
            pageBackground
                .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onChange(of: scenePhase) { _, newPhase in
            // Coming back from the registration site: ask how it went.
            guard newPhase == .active, awaitingReturnFromRegistration else { return }
            awaitingReturnFromRegistration = false
            if !isRegistered {
                showDidRegisterPrompt = true
            }
        }
        .alert("Did you register for the event?", isPresented: $showDidRegisterPrompt) {
            Button("Yes, I registered") {
                registeredStore.markRegistered(event.id)
                Task {
                    if let userId = home.currentUserId {
                        await registrationService.register(eventId: event.id, userId: userId)
                    }
                    await loadAttendees()
                }
                Task {
                    createdGroupExisted = !(await home.createGroup(for: event, description: resolvedDescription))
                    showGroupCreatedAlert = true
                }
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text("If you're going to \"\(event.title)\", SuperDex can create a deck so you can add the people you meet there.")
        }
        .alert(
            createdGroupExisted ? "You're all set" : "Deck created 🎉",
            isPresented: $showGroupCreatedAlert
        ) {
            Button("Go to deck") {
                groupToOpen = eventGroup
            }
            Button("Close", role: .cancel) {}
        } message: {
            Text(createdGroupExisted
                ? "This event is marked as registered. Your deck \"\(event.title)\" is already in the Deck tab — add the people you meet there."
                : "I've created \"\(event.title)\" in your Deck tab with the event details. Start adding the people you meet to keep networking after the event.")
        }
        .navigationDestination(item: $groupToOpen) { group in
            GroupDetailView(group: group)
        }
        .task {
            guard event.descriptionText == nil, loadedDescription == nil else { return }
            isLoadingDescription = true
            loadedDescription = await Scraper.fetchEventDescription(from: event.registrationURL)
            isLoadingDescription = false
        }
        .task {
            registeredStore.activate(userId: home.currentUserId)
            await loadAttendees()
            await requestVM.refresh()
        }
        .sheet(isPresented: $showAllAttendees) {
            EventAttendeesSheet(
                eventTitle: event.title,
                attendees: attendees,
                currentUserId: home.currentUserId
            )
        }
    }

    // MARK: - Page background

    private var pageBackground: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)

            LinearGradient(
                colors: [
                    accent.opacity(0.55),
                    accent.opacity(0.20),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            RadialGradient(
                colors: [accent.opacity(0.30), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
        }
    }

    // MARK: - Top bar

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

            ShareLink(item: event.registrationURL) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            ZStack(alignment: .bottom) {
                heroBackground(side: side)

                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: side, height: 80)
                .allowsHitTesting(false)

                heroBadge
                    .frame(width: side)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.50), radius: 24, y: 14)
    }

    @ViewBuilder
    private func heroBackground(side: CGFloat) -> some View {
        if let imageURL = event.imageURL {
            CachedAsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                gradientHero
            }
            .frame(width: side, height: side)
            .clipped()
            .allowsHitTesting(false)
        } else {
            gradientHero
                .frame(width: side, height: side)
        }
    }

    private var gradientHero: some View {
        ZStack {
            LinearGradient(
                colors: [accent, accent.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [.white.opacity(0.18), .clear],
                center: UnitPoint(x: 0.2, y: 0.2),
                startRadius: 0,
                endRadius: 220
            )

            Image(systemName: event.category.icon)
                .font(.system(size: 90, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var heroBadge: some View {
        HStack(spacing: 14) {
            Image(systemName: event.source.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text("LISTED ON \(event.source.displayName.uppercased())")
                .font(.gilroy(.semiBold, size: 12))
                .tracking(2.2)
                .foregroundStyle(.white)

            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(accent.opacity(0.55))
        .background(.ultraThinMaterial)
    }

    // MARK: - Title section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.title)
                .font(.gilroy(.bold, size: 30))
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            categoryTag

            infoChips
                .padding(.top, 4)

            eventLinkRow

            if let venue = event.venue, !venue.isEmpty {
                venueCaption(venue)
            }

            pricePill

            if let desc = resolvedDescription, !desc.isEmpty {
                descriptionCard(desc)
                    .padding(.top, 6)
            } else if isLoadingDescription {
                descriptionLoadingCard
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryTag: some View {
        HStack(spacing: 6) {
            Image(systemName: event.category.icon)
                .font(.system(size: 11, weight: .bold))
            Text(event.category.displayName)
                .font(.gilroy(.semiBold, size: 12))
                .tracking(1.0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(event.category.color.opacity(0.35)))
        .overlay(Capsule().strokeBorder(event.category.color.opacity(0.7), lineWidth: 1))
    }

    // Mirrors GroupDetailView's chip row: location, date, time.
    @ViewBuilder
    private var infoChips: some View {
        HStack(spacing: 10) {
            glassChip(icon: "mappin.and.ellipse", text: event.city)

            if let date = event.startDate {
                glassChip(icon: "calendar", text: dateOnlyString(date))
                glassChip(icon: "clock", text: timeOnlyString(date))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func venueCaption(_ venue: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))

            Text(venue)
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
        }
        .padding(.leading, 4)
    }

    // One big pill for the price, like GroupDetailView's hero badge.
    @ViewBuilder
    private var pricePill: some View {
        if let price = event.priceText {
            let isFree = price.localizedCaseInsensitiveContains("free")
            HStack(spacing: 10) {
                Image(systemName: isFree ? "gift.fill" : "tag.fill")
                    .font(.system(size: 13, weight: .semibold))

                Text(isFree ? "FREE EVENT" : price.uppercased())
                    .font(.gilroy(.semiBold, size: 14))
                    .tracking(1.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(accent.opacity(0.35)))
            .overlay(Capsule().strokeBorder(accent.opacity(0.7), lineWidth: 1))
            .padding(.top, 4)
        }
    }

    private var descriptionLoadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.white)

            Text("Loading event details…")
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// Rough size at which 15pt body text exceeds the collapsed
    /// 4-line limit — below this the toggle would do nothing.
    private var descriptionNeedsToggle: Bool {
        (resolvedDescription?.count ?? 0) > 180
    }

    @ViewBuilder
    private func descriptionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About this event")
                .font(.gilroy(.semiBold, size: 14))
                .foregroundStyle(.white.opacity(0.45))

            Text(text)
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(3)
                .lineLimit(isDescriptionExpanded ? nil : 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if descriptionNeedsToggle {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isDescriptionExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(isDescriptionExpanded ? "Show less" : "Read more")
                            .font(.gilroy(.semiBold, size: 13))
                        Image(systemName: isDescriptionExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.22),
                            .white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }

    @ViewBuilder
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
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .padding(.horizontal, 10)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    // MARK: - Who's going

    /// Sample events have non-UUID ids and no server rows, so the
    /// attendee list only exists for real (scraped) events.
    private var isServerEvent: Bool { UUID(uuidString: event.id) != nil }

    private let maxVisibleAttendees = 6

    private func loadAttendees() async {
        guard isServerEvent else { return }
        isLoadingAttendees = true
        if let fetched = await registrationService.fetchAttendees(eventId: event.id) {
            attendees = fetched
            // The server owns the registered mark — reconcile the
            // local cache with it, so a mark left by another account
            // on this device (or a cancel made elsewhere) disappears.
            if let userId = home.currentUserId {
                let registeredOnServer = fetched.contains { $0.id == userId }
                if registeredOnServer != isRegistered {
                    registeredOnServer
                        ? registeredStore.markRegistered(event.id)
                        : registeredStore.unmarkRegistered(event.id)
                }
            }
        }
        isLoadingAttendees = false
    }

    @ViewBuilder
    private var attendeesSection: some View {
        // Only worth showing once someone has actually registered; an
        // empty (or still-loading) list just renders as a hollow card.
        if isServerEvent && !attendees.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Attendees on SuperDex")
                        .font(.gilroy(.semiBold, size: 14))
                        .foregroundStyle(.white.opacity(0.45))

                    Spacer()

                    Text("\(attendees.count)")
                        .font(.gilroy(.bold, size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accent.opacity(0.35)))
                        .overlay(Capsule().strokeBorder(accent.opacity(0.7), lineWidth: 1))
                }

                VStack(spacing: 12) {
                    ForEach(attendees.prefix(maxVisibleAttendees)) { attendee in
                        attendeeRow(attendee)
                    }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showAllAttendees = true
                } label: {
                    HStack(spacing: 5) {
                        Text(attendees.count > maxVisibleAttendees
                            ? "See all \(attendees.count) people"
                            : "See everyone going")
                            .font(.gilroy(.semiBold, size: 13))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.22),
                                .white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        }
    }

    /// Mirrors ProfileViewersSheet: connected once they're in
    /// contacts (i.e. the request was accepted), pending while a
    /// sent request awaits an answer.
    private func connectState(for attendee: EventAttendee) -> DiscoverConnectState {
        if contactsVM.contactExists(contactUserId: attendee.id) { return .connected }
        switch requestVM.sentStatuses[attendee.id] {
        case .pending:          return .pending
        case .accepted:         return .connected
        case .rejected, .none:  return .connect
        }
    }

    private func attendeeRow(_ attendee: EventAttendee) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if attendee.avatar.isEmpty {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .clipShape(Circle())
            } else {
                Image(attendee.avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(attendee.fullName)
                        .font(.gilroy(.bold, size: 15))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if attendee.id == home.currentUserId {
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
                        .font(.gilroy(.medium, size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                if !attendee.bio.isEmpty {
                    Text(attendee.bio)
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if attendee.id == home.currentUserId {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.15, green: 0.65, blue: 0.40))
                    .padding(.top, 10)
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
    }

    // MARK: - Register

    @ViewBuilder
    private var registerSection: some View {
        if isRegistered {
            VStack(spacing: 10) {
                registeredButton

                Text("Tap if your plans changed and you want to undo this.")
                    .font(.gilroy(.regular, size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        } else {
            VStack(spacing: 10) {
                registerButton

                Text("You'll be taken to \(event.source.displayName) to complete registration.")
                    .font(.gilroy(.regular, size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var registerButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            awaitingReturnFromRegistration = true
            openURL(event.registrationURL)
        } label: {
            heroButtonLabel(
                icon: event.source.icon,
                title: "Register on \(event.source.displayName)",
                trailingIcon: "arrow.up.right",
                color: accent
            )
        }
        .buttonStyle(GroupCardPressStyle())
    }

    /// Same size and aesthetics as the register button, in green.
    /// Tapping offers to cancel the registration (undo).
    private var registeredButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showCancelRegistrationPrompt = true
        } label: {
            heroButtonLabel(
                icon: "checkmark.seal.fill",
                title: "You're Registered",
                trailingIcon: "chevron.down",
                color: Color(red: 0.15, green: 0.65, blue: 0.40)
            )
        }
        .buttonStyle(GroupCardPressStyle())
        .confirmationDialog(
            "Cancel registration?",
            isPresented: $showCancelRegistrationPrompt,
            titleVisibility: .visible
        ) {
            Button("Cancel registration", role: .destructive) {
                registeredStore.unmarkRegistered(event.id)
                Task {
                    if let userId = home.currentUserId {
                        await registrationService.unregister(eventId: event.id, userId: userId)
                    }
                    await loadAttendees()
                }
            }
            Button("Keep registration", role: .cancel) {}
        } message: {
            Text("This only removes the registered mark in SuperDex — your deck stays, and any actual booking on \(event.source.displayName) is unaffected.")
        }
    }

    private func heroButtonLabel(
        icon: String,
        title: String,
        trailingIcon: String?,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))

            Text(title)
                .font(.gilroy(.bold, size: 16))
                .tracking(0.5)

            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.system(size: 13, weight: .bold))
            }
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
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.5), radius: 16, y: 8)
    }

    /// The event's page link, tappable to open it, with a copy
    /// shortcut. Sits under the location/date/time chips.
    private var eventLinkRow: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openURL(event.registrationURL)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)

                    Text(event.registrationURL.absoluteString)
                        .font(.gilroy(.medium, size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .padding(.horizontal, 14)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                UIPasteboard.general.string = event.registrationURL.absoluteString
                linkCopied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    linkCopied = false
                }
            } label: {
                Image(systemName: linkCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(linkCopied ? .green : .white)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func dateOnlyString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func timeOnlyString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: SampleEvents.make()[0])
    }
    .environment(HomeViewModel())
    .environment(ContactRequestViewModel())
    .environment(ContactsViewModel())
    .preferredColorScheme(.dark)
}
