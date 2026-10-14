//
//  GroupsView.swift
//  SuperDex
//
//  Full list of the user's groups. Pushed from HomeView's
//  "Your decks → See all", and the root of the Deck tab.
//

import SwiftUI

struct GroupsView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(UserProfileViewModel.self) private var profileVM
    @Environment(EventsViewModel.self) private var eventsVM

    /// Local pending-deletion state: HomeView's delete alert can't
    /// present while this pushed view covers it, so the confirmation
    /// lives here.
    @State private var groupPendingDeletion: CardGroup?
    @State private var searchText = ""
    @State private var showsDeckInfo = false
    /// Event whose deck is being created (shows a spinner on its button).
    @State private var creatingDeckForEventID: String?
    /// Event whose deck was just created/found, for the confirmation alert.
    @State private var eventDeckResult: (event: AppEvent, existed: Bool)?
    /// Pushed by the alert's "Go to deck".
    @State private var groupToOpen: CardGroup?
    @FocusState private var isSearchFocused: Bool

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleGroups: [CardGroup] {
        guard !trimmedQuery.isEmpty else { return viewModel.groups }
        return viewModel.groups.filter { HomeViewModel.group($0, matches: trimmedQuery) }
    }

    /// Deck tab only: the same search also finds upcoming events — all of
    /// them, not just this week's or the selected city/platform.
    private var matchingEvents: [AppEvent] {
        guard !showsBackButton, !trimmedQuery.isEmpty else { return [] }
        return eventsVM.events.filter { $0.matches(trimmedQuery) }
    }

    private var isSearching: Bool { !trimmedQuery.isEmpty }

    var title: String = "Your Decks"
    /// False when shown as a tab root (Deck): uses the large tab header
    /// instead of the back-button top bar.
    var showsBackButton: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if showsBackButton {
                        Color.clear.frame(height: 52)

                        Text(groupCountText)
                            .font(.gilroy(.medium, size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 20)
                    } else {
                        tabHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 10)
                    }

                    // Deck tab: searches decks and events, so it's there
                    // from the start, before the first deck.
                    if !showsBackButton || !viewModel.groups.isEmpty {
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                    }

                    if isSearching {
                        if !matchingEvents.isEmpty {
                            searchResultsHeading("Events", count: matchingEvents.count)
                            eventResults
                        }
                        if !visibleGroups.isEmpty && !matchingEvents.isEmpty {
                            searchResultsHeading("Decks", count: visibleGroups.count)
                                .padding(.top, 12)
                        }
                    } else if viewModel.groups.isEmpty {
                        // Decks for this week's events, then make your
                        // own. "What's a deck?" lives behind the ⓘ button.
                        if showsEventsThisWeek {
                            eventsThisWeekSection
                                .padding(.top, 4)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            sectionHeading(
                                showsEventsThisWeek ? "Or start your own deck" : "Start your first deck",
                                subtitle: "Group people any way you like: by role, company, skill, or team."
                            )
                            firstDeckGuide(.howTo)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, showsEventsThisWeek ? sectionGap : 4)
                        .padding(.bottom, 56)
                    } else {
                        if showsEventsThisWeek {
                            eventsThisWeekSection
                                .padding(.top, 8)
                                .padding(.bottom, sectionGap - 18)
                        }

                        sectionHeading("Your decks", subtitle: groupCountText)
                            .padding(.horizontal, 20)
                    }

                    if isSearching && visibleGroups.isEmpty && matchingEvents.isEmpty {
                        noResults
                    }

                    LazyVStack(spacing: 16) {
                        ForEach(visibleGroups) { group in
                            SwipeActionRow(
                                accent: group.color,
                                onEdit: { viewModel.groupBeingEdited = group },
                                onDelete: { groupPendingDeletion = group }
                            ) {
                                NavigationLink(value: group) {
                                    GroupCardView(group: group)
                                }
                                .buttonStyle(GroupCardPressStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 56)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .reportsTopScroll()
            .scrollDismissesKeyboard(.interactively)

            if showsBackButton {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
        .background(AppBackground())
        .navigationBarHidden(true)
        .sheet(isPresented: $showsDeckInfo) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    firstDeckGuide(.intro)

                    // Same "Got it" as the Contacts ⓘ sheet.
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showsDeckInfo = false
                    } label: {
                        Text("Got it")
                            .font(.gilroy(.semiBold, size: 16))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(.white)
                            )
                    }
                    .buttonStyle(GroupCardPressStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .presentationDetents([.fraction(0.72), .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            guard !showsBackButton else { return }
            await eventsVM.loadIfNeeded()
        }
        // Same confirmation EventDetailView shows after "Yes, I registered".
        .alert(
            eventDeckResult?.existed == true ? "You're all set" : "Deck created 🎉",
            isPresented: Binding(
                get: { eventDeckResult != nil },
                set: { if !$0 { eventDeckResult = nil } }
            ),
            presenting: eventDeckResult
        ) { result in
            Button("Go to deck") {
                groupToOpen = viewModel.group(for: result.event)
            }
            Button("Close", role: .cancel) {}
        } message: { result in
            Text(result.existed
                ? "Your deck \"\(result.event.title)\" is already in the Deck tab — add the people you meet there."
                : "I've created \"\(result.event.title)\" in your Deck tab with the event details. Start adding the people you meet to keep networking after the event.")
        }
        .navigationDestination(item: $groupToOpen) { group in
            GroupDetailView(
                group: group,
                onEdit: { viewModel.groupBeingEdited = group }
            )
        }
        .alert(
            "Delete Deck?",
            isPresented: Binding(
                get: { groupPendingDeletion != nil },
                set: { if !$0 { groupPendingDeletion = nil } }
            ),
            presenting: groupPendingDeletion
        ) { group in
            Button("Delete", role: .destructive) {
                viewModel.deleteGroup(id: group.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { group in
            Text("\"\(group.name)\" will be permanently deleted. This cannot be undone.")
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            TextField(
                "",
                text: $searchText,
                prompt: Text(showsBackButton ? "Search decks, members, places" : "Search decks, people, events")
                    .font(.gilroy(.regular, size: 15))
                    .foregroundColor(.white.opacity(0.55))
            )
            .font(.gilroy(.regular, size: 16))
            .foregroundStyle(.white)
            .tint(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
            .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isSearchFocused ? 0.10 : 0.06))
        )
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: isSearchFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: searchText.isEmpty)
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            isSearchFocused = true
        }
    }

    private var noResults: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(showsBackButton
                 ? "No decks match \"\(trimmedQuery)\""
                 : "No decks or events match \"\(trimmedQuery)\"")
                .font(.gilroy(.semiBold, size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
    }

    // MARK: - Search results

    private func searchResultsHeading(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.gilroy(.semiBold, size: 12))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.55))
            Text("\(count)")
                .font(.gilroy(.semiBold, size: 12))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    /// Matching events, each with the same Create / Open deck button as
    /// the This Week carousel. Tapping the card opens the event page.
    private var eventResults: some View {
        LazyVStack(spacing: 16) {
            ForEach(matchingEvents) { event in
                VStack(spacing: 10) {
                    NavigationLink(value: event) {
                        EventCardView(event: event)
                    }
                    .buttonStyle(GroupCardPressStyle())

                    weekEventAction(for: event)
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: - Happening this week

    /// Only on the Deck tab root, out of the way while searching, and
    /// hidden if there are no events at all (filters stay reachable
    /// when they just narrow this week's list to nothing).
    private var showsEventsThisWeek: Bool {
        !showsBackButton && trimmedQuery.isEmpty
            && (eventsVM.isLoading || !eventsVM.events.isEmpty)
    }

    /// Home's "Upcoming events" block (same filters), plus a nudge to
    /// make a deck for the event you're going to.
    private var eventsThisWeekSection: some View {
        UpcomingEventsSection(
            viewModel: eventsVM,
            allEventsRoute: DeckRoute.allEvents,
            title: "Events This Week",
            subtitle: "Create a deck for the event you're going to."
        ) { event in
            weekEventAction(for: event)
                .padding(.horizontal, 8)
        }
    }

    /// "Create deck" for a new event, or "Open deck" once the user has one.
    @ViewBuilder
    private func weekEventAction(for event: AppEvent) -> some View {
        if let existingDeck = viewModel.group(for: event) {
            NavigationLink(value: existingDeck) {
                weekEventActionLabel("Open deck", icon: "checkmark.circle.fill", filled: false)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await createDeck(for: event) }
            } label: {
                weekEventActionLabel(
                    "Create deck",
                    icon: "plus",
                    filled: true,
                    isLoading: creatingDeckForEventID == event.id
                )
            }
            .buttonStyle(.plain)
            .disabled(creatingDeckForEventID != nil)
        }
    }

    /// Creates the event's deck the same way EventDetailView does when
    /// the user confirms they're attending: event details, description
    /// (fetched from the event page if the listing lacks one) and image.
    private func createDeck(for event: AppEvent) async {
        creatingDeckForEventID = event.id
        defer { creatingDeckForEventID = nil }

        var description = event.descriptionText
        if description == nil {
            description = await Scraper.fetchEventDescription(from: event.registrationURL)
        }
        let created = await viewModel.createGroup(for: event, description: description)
        eventDeckResult = (event, !created)
    }

    private func weekEventActionLabel(
        _ title: String,
        icon: String,
        filled: Bool,
        isLoading: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(filled ? .black : .white)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
            }
            Text(isLoading ? "Creating deck…" : title)
                .font(.gilroy(.semiBold, size: 15))
        }
        .foregroundStyle(filled ? .black : .white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Capsule().fill(filled ? Color.white : Color.clear))
        .glassEffect(filled ? .identity : .regular.interactive(), in: Capsule())
        .contentShape(Capsule())
    }

    // MARK: - Section headings

    /// Space between the Deck tab's sections.
    private let sectionGap: CGFloat = 36

    /// Shared heading so the guide, events and deck list read as one page.
    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        // Matches EmptyStateGuide's "Decks are stacks of people" title.
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.gilroy(.bold, size: 30))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.gilroy(.regular, size: 16))
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - First-run guide

    /// `.howTo` is shown instead of the search bar + list until the user
    /// has a deck; `.intro` ("what's a deck") is the ⓘ sheet by the title.
    private func firstDeckGuide(_ part: EmptyStateGuide.Part) -> some View {
        EmptyStateGuide(
            icon: "person.2.fill",
            accent: .indigo,
            title: "Decks are stacks of people",
            subtitle: "Organize the people you meet into Decks based on their job roles, companies, skills, or events.\n\nWith Decks, everyone is in one place. Easily find connections, explore their latest profiles, and stay up to date with their details, so you never lose track of someone important.",
            steps: [
                .init(
                    icon: "plus",
                    title: "Create a deck",
                    detail: "Tap the + button and give it a name, like \u{201C}Design Meetup\u{201D}."
                ),
                .init(
                    icon: "calendar.badge.clock",
                    title: "Add the details",
                    detail: "Optionally set a date, location, link, and a cover photo."
                ),
                .init(
                    icon: "person.2.fill",
                    title: "Add people",
                    detail: "Pick from your contacts, or scan someone's SuperDex QR to add them straight in."
                ),
                .init(
                    icon: "magnifyingglass",
                    title: "Find them later",
                    detail: "Search your decks by name, member, or place whenever you need to reconnect."
                )
            ],
            primaryTitle: "Create a Deck",
            primaryAction: { viewModel.prepareNewGroup() },
            part: part
        )
    }

    private var groupCountText: String {
        "\(viewModel.groups.count) deck\(viewModel.groups.count == 1 ? "" : "s")"
    }

    /// Large header matching the other tab roots (Home, Contacts, Discover).
    private var tabHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Image((subscription.isPro || profileVM.profile.hasPro) ? "SuperDexProText" : "SuperDexText")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)

                HStack(alignment: .center, spacing: 10) {
                    Text(title)
                        .font(.gilroy(.bold, size: 42))
                        .foregroundStyle(.white)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showsDeckInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("What is a deck?")
                }

//                Text(groupCountText)
//                    .font(.gilroy(.medium, size: 14))
//                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.prepareNewGroup()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
                    .glassEffect(.clear.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .accessibilityLabel("New deck")
        }
    }

    private var topBar: some View {
        ZStack {
            Text(title)
                .font(.gilroy(.bold, size: 20))
                .foregroundStyle(.white)

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

                Button {
                    viewModel.prepareNewGroup()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupsView()
    }
    .environment(HomeViewModel())
    .environment(SubscriptionManager())
    .environment(UserProfileViewModel())
    .environment(EventsViewModel())
    .preferredColorScheme(.dark)
}
