//
//  ContactsView.swift
//  HomeScreen
//

import SwiftUI

struct ContactsView: View {
    @Environment(ContactsViewModel.self) private var viewModel
    @Environment(UserProfileViewModel.self) private var profileVM
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(DeviceContactsViewModel.self) private var deviceVM
    @Environment(ContactRequestViewModel.self) private var contactRequestVM
    @Environment(\.openScanner) private var openScanner
    @State private var showsContactsInfo = false
    /// Logged meetings per contact, so search can match where you met
    /// someone and what you talked about.
    @State private var meetingsByContact: [UUID: [EventMeeting]] = [:]
    private let meetingService = MeetingService()
    @State private var selectedContact: Contact?
    @State private var isSelecting: Bool = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showAddToGroup: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    // Phone-book section. Device contacts are keyed by CNContact.identifier,
    // so selection needs its own set alongside the SuperDex one.
    @State private var scope: ContactsScope = .superdex
    @State private var deviceFilter: DeviceContactFilter = .onSuperDex
    @State private var selectedDeviceIds: Set<String> = []
    @State private var selectedDeviceProfile: ProfileCard?
    @AppStorage("contactsLayoutStyle") private var layoutStyle: ContactsLayoutStyle = .glass
    @State private var searchText: String = ""
    @State private var selectedCategory: ProfileCategory? = nil
    @FocusState private var isSearchFocused: Bool
    @Namespace private var contactNamespace
    private var userProfile: UserProfileData { profileVM.profile }

    // How far the user has pulled past the top edge (0 when not overscrolling).
    // Drives the deck-fan physics on the stacked color rows.
    @State private var pullStretch: CGFloat = 0
    @State private var hasTriggeredStretchHaptic = false

    private var contacts: [Contact] { viewModel.contacts }

    private var filteredContacts: [Contact] {
        var result = contacts

        if let category = selectedCategory {
            result = result.filter { $0.categories.contains(category) }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result }
        let digitsQuery = query.filter(\.isNumber)
        return result.filter { contact in
            let card = contact.asProfileCard
            if card.name.localizedCaseInsensitiveContains(query) { return true }
            if card.jobRole.localizedCaseInsensitiveContains(query) { return true }
            if card.companyName.localizedCaseInsensitiveContains(query) { return true }
            if card.email.localizedCaseInsensitiveContains(query) { return true }
            if card.phone.localizedCaseInsensitiveContains(query) { return true }
            if !digitsQuery.isEmpty {
                let phoneDigits = card.phone.filter(\.isNumber)
                if phoneDigits.contains(digitsQuery) { return true }
            }
            let meetings = meetingsByContact[contact.contactUserId] ?? []
            return meetings.contains { meeting in
                meeting.eventName.localizedCaseInsensitiveContains(query)
                    || meeting.location.localizedCaseInsensitiveContains(query)
                    || meeting.notes.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 28)
                            .padding(.bottom, 14)

                        scopePicker
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)

                        switch scope {
                        case .superdex:
                            if contacts.isEmpty {
                                // --NEW_USER_CUI: first-run guide until the
                                // first SuperDex contact is saved.
                                newUserGuide
                                    .padding(.top, 8)
                            } else {
                                contactCategoryChips
                                    .padding(.bottom, 18)

                                if filteredContacts.isEmpty {
                                    noResultsState
                                        .padding(.top, 60)
                                } else {
                                    contactList
                                }
                            }

                        case .phone:
                            deviceContactsSection
                        }
                    }
                }
                .reportsTopScroll()
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
                } action: { _, pulled in
                    pullStretch = pulled
                    if pulled > 20 && !hasTriggeredStretchHaptic {
                        hasTriggeredStretchHaptic = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else if pulled <= 5 {
                        hasTriggeredStretchHaptic = false
                    }
                }
                .refreshable {
                    switch scope {
                    case .superdex:
                        await viewModel.refresh()
                        await loadMeetings()
                    case .phone:
                        await deviceVM.refresh()
                    }
                }
                .background(AppBackground())

                if isSelecting && !activeSelectionIsEmpty {
                    selectionActionBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                // Meetings may have been added/edited on a profile screen.
                Task { await loadMeetings() }
            }
            .sheet(isPresented: $showsContactsInfo) {
                ContactsInfoSheet()
            }
            .task(id: scope) {
                guard scope == .phone else { return }
                deviceVM.configure(userId: viewModel.currentUserId)
                await deviceVM.loadIfNeeded()
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelecting)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedIds)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedDeviceIds)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: scope)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: deviceFilter)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: layoutStyle)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedCategory)
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedContact) { contact in
                ProfileDetailView(profile: contact.asProfileCard)
                    .navigationTransition(.zoom(sourceID: contact.id, in: contactNamespace))
            }
            .navigationDestination(item: $selectedDeviceProfile) { card in
                // Already connected: the same page as tapping them in the list.
                // Otherwise isDiscovery: the phone match carries identity only,
                // so the detail screen shows the Connect flow.
                if let contact = viewModel.savedContact(for: card) {
                    ProfileDetailView(profile: contact.asProfileCard)
                } else {
                    ProfileDetailView(profile: card, isDiscovery: true)
                }
            }
            .sheet(isPresented: $showAddToGroup) {
                AddToGroupSheet(members: activeSelectedMembers) {
                    selectedIds.removeAll()
                    selectedDeviceIds.removeAll()
                    isSelecting = false
                }
            }
            .alert(
                "Delete \(selectedIds.count) Contact\(selectedIds.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        let ids = selectedIds
                        if await viewModel.deleteContacts(ids: ids) {
                            selectedIds.removeAll()
                            isSelecting = false
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Contact list

    @ViewBuilder
    private var contactList: some View {
        switch layoutStyle {
        case .color:
            LazyVStack(spacing: -40) {
                ForEach(Array(filteredContacts.enumerated()), id: \.element.id) { index, contact in
                    ColorContactRow(
                        contact: contact.asProfileCard,
                        isSelecting: isSelecting,
                        isSelected: selectedIds.contains(contact.id),
                        isLast: index == filteredContacts.count - 1
                    )
                    .matchedTransitionSource(id: contact.id, in: contactNamespace)
                    .modifier(
                        ColorContactViewDeckPhysics(
                            index: index,
                            stretch: pullStretch
                        )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if isSelecting {
                            toggle(contact)
                        } else {
                            selectedContact = contact
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, isSelecting && !selectedIds.isEmpty ? 96 : 16)

        case .glass:
            LazyVStack(spacing: 18) {
                ForEach(filteredContacts) { contact in
                    GlassContactRow(
                        contact: contact.asProfileCard,
                        isSelecting: isSelecting,
                        isSelected: selectedIds.contains(contact.id)
                    )
                    .matchedTransitionSource(id: contact.id, in: contactNamespace)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if isSelecting {
                            toggle(contact)
                        } else {
                            selectedContact = contact
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, isSelecting && !selectedIds.isEmpty ? 96 : 16)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Image((subscription.isPro || userProfile.hasPro) ? "SuperDexProText" : "SuperDexText")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)

                HStack(alignment: .center, spacing: 10) {
                    Text("Contacts")
                        .font(.gilroy(.bold, size: 42))
                        .foregroundStyle(.white)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showsContactsInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("About Contacts")
                }
            }

            Spacer()

            moreMenu
                .padding(.top, 16)
        }
    }

    private var moreMenu: some View {
        Menu {
            if scope == .superdex {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        layoutStyle.toggle()
                    }
                } label: {
                    Label(
                        layoutStyle == .color ? "Minimal Layout" : "Colorful Layout",
                        systemImage: layoutStyle == .color ? "rectangle.stack.fill" : "square.stack.3d.up.fill"
                    )
                }
            }

            Button {
                withAnimation {
                    isSelecting.toggle()
                    if !isSelecting {
                        selectedIds.removeAll()
                        selectedDeviceIds.removeAll()
                    }
                }
            } label: {
                Label(
                    isSelecting ? "Cancel" : "Add to Deck",
                    systemImage: isSelecting ? "xmark.circle" : "person.2.badge.plus"
                )
            }

            if !isSelecting && scope == .superdex {
                Button(role: .destructive) {
                    withAnimation {
                        isSelecting = true
                    }
                } label: {
                    Label("Remove Contacts", systemImage: "person.crop.circle.badge.minus")
                }
            }

            if scope == .phone {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    InviteService.share(
                        text: InviteService.message(for: "", from: userProfile.fullName)
                    )
                } label: {
                    Label("Share Invite Link", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .glassEffect(.clear.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection action bar

    private var selectionActionBar: some View {
        HStack(spacing: 12) {
            Button {
                showAddToGroup = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.badge.plus.fill")
                        .font(.gilroy(.semiBold, size: 17))
                    Text("Add to Deck")
                        .font(.gilroy(.semiBold, size: 15))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white)
                )
            }
            .buttonStyle(.plain)

            // Deleting is only meaningful for saved SuperDex contacts — the
            // phone list is the device's address book, not ours to edit.
            if scope == .superdex {
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.gilroy(.semiBold, size: 17))
                    Text("Delete")
                        .font(.gilroy(.semiBold, size: 15))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.red)
                )
            }
            .buttonStyle(.plain)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }

    // MARK: - Selection

    private func toggle(_ contact: Contact) {
        if selectedIds.contains(contact.id) {
            selectedIds.remove(contact.id)
        } else {
            selectedIds.insert(contact.id)
        }
    }

    private var selectedMembers: [GroupMember] {
        contacts
            .filter { selectedIds.contains($0.id) }
            .map { $0.asGroupMember }
    }

    // MARK: - Scope

    /// Switches the list between saved SuperDex contacts and the device
    /// address book. Selection is per-scope, so flipping over mid-selection
    /// clears the other side rather than silently carrying it along.
    private var scopePicker: some View {
        HStack(spacing: 6) {
            ForEach(ContactsScope.allCases) { option in
                let isActive = scope == option
                Button {
                    guard scope != option else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        scope = option
                        selectedIds.removeAll()
                        selectedDeviceIds.removeAll()
                        isSelecting = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(option.title)
                            .font(.gilroy(.semiBold, size: 14))
                        if let count = scopeCount(option) {
                            Text("\(count)")
                                .font(.gilroy(.semiBold, size: 12))
                                .foregroundStyle(isActive ? .black.opacity(0.55) : .white.opacity(0.5))
                        }
                    }
                    .foregroundStyle(isActive ? .black : .white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Capsule().fill(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.clear))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
    }

    private func scopeCount(_ option: ContactsScope) -> Int? {
        switch option {
        case .superdex:
            return contacts.isEmpty ? nil : contacts.count
        case .phone:
            return deviceVM.entries.isEmpty ? nil : deviceVM.entries.count
        }
    }

    // MARK: - Device contacts (From Phone)

    private var filteredDeviceEntries: [DeviceContactEntry] {
        var result = deviceVM.entries

        switch deviceFilter {
        case .onSuperDex:    result = result.filter(\.isOnSuperDex)
        case .notOnSuperDex: result = result.filter { !$0.isOnSuperDex }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result }
        let digitsQuery = query.filter(\.isNumber)

        return result.filter { entry in
            if entry.name.localizedCaseInsensitiveContains(query) { return true }
            if entry.device.organizationName.localizedCaseInsensitiveContains(query) { return true }
            if entry.device.jobTitle.localizedCaseInsensitiveContains(query) { return true }
            if entry.device.emails.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
            if !digitsQuery.isEmpty {
                return entry.device.phoneNumbers.contains {
                    $0.filter(\.isNumber).contains(digitsQuery)
                }
            }
            return false
        }
    }

    @ViewBuilder
    private var deviceContactsSection: some View {
        if !deviceVM.accessState.canRead {
            DeviceContactsAccessCard(state: deviceVM.accessState) {
                Task { await deviceVM.requestAccessAndLoad() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if deviceVM.accessState == .limited {
                    LimitedAccessNotice()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }

                deviceFilterChips
                    .padding(.bottom, 18)

                if deviceVM.matchFailed {
                    matchFailedNotice
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }

                if deviceVM.isLoading && deviceVM.entries.isEmpty {
                    deviceLoadingState
                        .padding(.top, 60)
                } else if let error = deviceVM.errorMessage, deviceVM.entries.isEmpty {
                    deviceErrorState(error)
                        .padding(.top, 60)
                } else if deviceVM.entries.isEmpty && deviceVM.hasLoaded {
                    deviceEmptyState
                        .padding(.top, 70)
                } else if filteredDeviceEntries.isEmpty {
                    deviceNoResultsState
                        .padding(.top, 60)
                } else {
                    deviceList
                }
            }
        }
    }

    private var deviceList: some View {
        LazyVStack(spacing: 14) {
            ForEach(filteredDeviceEntries) { entry in
                deviceRow(entry)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, isSelecting && !selectedDeviceIds.isEmpty ? 96 : 16)
    }

    @ViewBuilder
    private func deviceRow(_ entry: DeviceContactEntry) -> some View {
        let isSelected = selectedDeviceIds.contains(entry.id)

        if let match = entry.match {
            // Already on SuperDex — same card as the rest of the app, with a
            // Connect pill instead of the call/email buttons, since we don't
            // hold their number until they accept.
            GlassContactRow(
                contact: match.card,
                isSelecting: isSelecting,
                isSelected: isSelected,
                connectState: isSelecting ? nil : connectState(for: match),
                onConnect: { sendConnect(match) },
                onWithdraw: { withdrawConnect(match) },
                onDisconnect: { disconnect(match) }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if isSelecting {
                    toggleDevice(entry)
                } else {
                    selectedDeviceProfile = match.card
                }
            }
        } else {
            DeviceContactRow(
                entry: entry,
                isSelecting: isSelecting,
                isSelected: isSelected,
                onInvite: { invite(entry) }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard isSelecting else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                toggleDevice(entry)
            }
        }
    }

    private var deviceFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DeviceContactFilter.allCases) { filter in
                    let isSelected = deviceFilter == filter
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            deviceFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(filter.title)
                                .font(.gilroy(.semiBold, size: 13))
                            if let count = deviceFilterCount(filter) {
                                Text("\(count)")
                                    .font(.gilroy(.semiBold, size: 12))
                                    .opacity(0.65)
                            }
                        }
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(isSelected
                                           ? AnyShapeStyle(.white)
                                           : AnyShapeStyle(.white.opacity(0.08)))
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? .clear : .white.opacity(0.15),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func deviceFilterCount(_ filter: DeviceContactFilter) -> Int? {
        guard deviceVM.hasLoaded else { return nil }
        switch filter {
        case .onSuperDex:    return deviceVM.onSuperDexCount
        case .notOnSuperDex: return deviceVM.inviteCount
        }
    }

    // MARK: - Device states

    private var deviceLoadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.white)
            Text("Matching your contacts\u{2026}")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var deviceEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.white.opacity(0.35))
            Text("No contacts on this device")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))
            Text("Contacts with a phone number will show up here.")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private func deviceErrorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.white.opacity(0.35))
            Text("Couldn't read your contacts")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))
            Text(message)
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private var deviceNoResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.white.opacity(0.35))
            Text("No matches")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))
            Text(isSearching
                 ? "No phone contacts match your search."
                 : deviceFilter == .onSuperDex
                    ? "None of your phone contacts are on SuperDex yet \u{2014} invite a few."
                    : "Everyone in your phone is already on SuperDex.")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    /// The address book loaded but the lookup didn't — say so, because
    /// otherwise everyone silently reads as "not on SuperDex".
    private var matchFailedNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.9))
            VStack(alignment: .leading, spacing: 3) {
                Text("Couldn't check who's on SuperDex. Pull to refresh.")
                    .font(.gilroy(.regular, size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                #if DEBUG
                if let detail = deviceVM.matchErrorMessage {
                    Text(detail)
                        .font(.gilroy(.regular, size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(3)
                }
                #endif
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
    }

    // MARK: - Device actions

    private func toggleDevice(_ entry: DeviceContactEntry) {
        if selectedDeviceIds.contains(entry.id) {
            selectedDeviceIds.remove(entry.id)
        } else {
            selectedDeviceIds.insert(entry.id)
        }
    }

    private func invite(_ entry: DeviceContactEntry) {
        InviteService.invite(
            name: entry.device.name,
            phone: entry.device.primaryPhone,
            senderName: userProfile.fullName
        )
    }

    private func connectState(for match: PhoneMatchedProfile) -> DiscoverConnectState {
        if contacts.contains(where: { $0.contactUserId == match.userId }) { return .connected }
        switch contactRequestVM.sentStatuses[match.userId] {
        case .pending:       return .pending
        case .accepted:      return .connected
        case .rejected, nil: return .connect
        }
    }

    private func sendConnect(_ match: PhoneMatchedProfile) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { await contactRequestVM.sendRequest(to: match.userId) }
    }

    private func withdrawConnect(_ match: PhoneMatchedProfile) {
        Task { await contactRequestVM.withdrawRequest(to: match.userId) }
    }

    private func disconnect(_ match: PhoneMatchedProfile) {
        Task {
            await contactRequestVM.disconnect(from: match.userId)
            await viewModel.refresh()
        }
    }

    // MARK: - Selection across both scopes

    private var activeSelectionIsEmpty: Bool {
        scope == .superdex ? selectedIds.isEmpty : selectedDeviceIds.isEmpty
    }

    private var activeSelectedMembers: [GroupMember] {
        switch scope {
        case .superdex:
            return selectedMembers
        case .phone:
            return deviceVM.entries
                .filter { selectedDeviceIds.contains($0.id) }
                .map { $0.asGroupMember }
        }
    }

    // MARK: - Category chips

    private var contactCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ProfileCategory.allCases) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedCategory = isSelected ? nil : category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(category.displayName)
                                .font(.gilroy(.semiBold, size: 13))
                        }
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(isSelected
                                      ? AnyShapeStyle(.white)
                                      : AnyShapeStyle(.white.opacity(0.08)))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? .clear : .white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - --NEW_USER_CUI
    // First-run Contacts guide ("Your people, all in one place" + steps +
    // Scan a QR Code), shown on the SuperDex tab while there are no
    // saved contacts.
    /// First-run guide: explains how people land in Contacts and how
    /// they flow into decks.
    private var newUserGuide: some View {
        EmptyStateGuide(
            icon: "person.crop.rectangle.fill",
            accent: Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0),
            title: "Your people, all in one place",
            subtitle: "Everyone you connect with on SuperDex lands here, with their card, role, and links ready whenever you need to follow up.",
            steps: [
                .init(
                    icon: "qrcode.viewfinder",
                    title: "Scan a card",
                    detail: "Scan someone's SuperDex QR code and tap Save to My Contacts."
                ),
                .init(
                    icon: "person.text.rectangle",
                    title: "Share yours",
                    detail: "Show your QR from Home \u{2192} My Card. When others scan it, you're one tap from connecting."
                ),
                .init(
                    icon: "globe",
                    title: "Connect on Discover",
                    detail: "Send a connect request; once it's accepted, they show up here."
                ),
                .init(
                    icon: "rectangle.stack.fill",
                    title: "Organize into decks",
                    detail: "Tap \u{2022}\u{2022}\u{2022} \u{2192} Add to Deck to group contacts by event, team, or trip."
                )
            ],
            primaryTitle: "Scan a QR Code",
            primaryIcon: "qrcode.viewfinder",
            primaryAction: { openScanner() }
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private func loadMeetings() async {
        guard let userId = viewModel.currentUserId else { return }
        do {
            meetingsByContact = try await meetingService.fetchAllByContact(userId: userId)
        } catch {
            print("Failed to load meetings for search: \(error.localizedDescription)")
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            TextField(
                "",
                text: $searchText,
                prompt: Text("Search name, role, company, where you met")
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

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.gilroy(.regular, size: 38))
                .foregroundStyle(.white.opacity(0.35))

            Text("No matches")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))

            if let category = selectedCategory, isSearching {
                Text("No \(category.displayName) contacts match \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\".")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else if let category = selectedCategory {
                Text("No contacts found in \(category.displayName).")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else {
                Text("No contacts match \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\".")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                if isSearching {
                    Button("Clear search") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        searchText = ""
                    }
                    .font(.gilroy(.semiBold, size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }

                if selectedCategory != nil {
                    Button("Clear filter") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedCategory = nil
                        }
                    }
                    .font(.gilroy(.semiBold, size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Layout style

enum ContactsLayoutStyle: String {
    case color
    case glass

    mutating func toggle() {
        self = self == .color ? .glass : .color
    }
}

// MARK: - ColorContactView — Stacked Deck Physics

/// Spreads the stacked color card deck on top-overscroll. Each card's spring
/// response is staggered by index so the deck cascades back into a stack on release.
private struct ColorContactViewDeckPhysics: ViewModifier {
    let index: Int
    let stretch: CGFloat

    // Saturating cap so the deck never fans wider than the original overlap —
    // cards always stay visually adjacent, no empty bands between them.
    private static let maxExtraGap: CGFloat = 32
    private static let stretchSoftness: CGFloat = 120

    func body(content: Content) -> some View {
        let depth = CGFloat(index)
        let progress = min(stretch / Self.stretchSoftness, 1)
        let extraGap = Self.maxExtraGap * progress
        let offsetY = depth * extraGap
        let scale = 1 + 0.03 * progress

        content
            .offset(y: offsetY)
            .scaleEffect(scale, anchor: .top)
            .animation(
                .spring(
                    response: 0.45 + Double(index) * 0.025,
                    dampingFraction: 0.68
                ),
                value: stretch
            )
    }
}

// MARK: - ColorContactRow (metallic theme-gradient, stacked deck)

// MARK: - Discover connection pill

enum DiscoverConnectState {
    case connect, pending, connected
}

struct DiscoverConnectPill: View {
    let state: DiscoverConnectState
    var action: () -> Void
    /// When set, tapping the "Pending" pill offers to withdraw the request.
    var onWithdraw: (() -> Void)? = nil
    /// When set, tapping the "Connected" pill offers to disconnect.
    var onDisconnect: (() -> Void)? = nil

    @State private var showWithdrawConfirm = false
    @State private var showDisconnectConfirm = false

    var body: some View {
        Button {
            if state == .connect {
                action()
            } else if state == .pending, onWithdraw != nil {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showWithdrawConfirm = true
            } else if state == .connected, onDisconnect != nil {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showDisconnectConfirm = true
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.gilroy(.semiBold, size: 13))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(background, in: Capsule())
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state)
        .confirmationDialog(
            "Withdraw connect request?",
            isPresented: $showWithdrawConfirm,
            titleVisibility: .visible
        ) {
            Button("Withdraw Request", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onWithdraw?()
            }
            Button("Keep Request", role: .cancel) {}
        }
        .confirmationDialog(
            "Disconnect?",
            isPresented: $showDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDisconnect?()
            }
            Button("Stay Connected", role: .cancel) {}
        } message: {
            Text("You'll be removed from each other's contacts. You can connect again anytime.")
        }
    }

    private var icon: String? {
        switch state {
        case .connect:   return "link.badge.plus"
        case .pending:   return "clock.fill"
        case .connected: return nil
        }
    }

    private var label: String {
        switch state {
        case .connect:   return "Connect"
        case .pending:   return "Pending"
        case .connected: return "Connected"
        }
    }

    private var background: Color {
        switch state {
        case .connect:   return .white.opacity(0.12)
        case .pending:   return .white.opacity(0.06)
        case .connected: return .white.opacity(0.12)
        }
    }
}

struct ColorContactRow: View {
    let contact: ProfileCard
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var isLast: Bool = false
    var connectState: DiscoverConnectState? = nil
    var onConnect: (() -> Void)? = nil
    var onWithdraw: (() -> Void)? = nil
    var onDisconnect: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    private let cornerRadius: CGFloat = 24
    private let stackOverlap: CGFloat = 40

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .padding(.top, 36)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            card
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelecting)
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 14) {
            // Avatar and Pro pill stacked as one unit so layout accounts
            // for the badge height instead of it hanging below the frame.
            VStack(spacing: -3) {
                Image(contact.avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)

                if contact.isPremiumUser {
                    ProBadge(height: 14)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name)
                    .font(.gilroy(.semiBold, size: 19))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .lineLimit(1)

                Text(contact.jobRole.uppercased())
                    .font(.gilroy(.semiBold, size: 11))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)

                if !contact.bio.isEmpty {
                    Text(contact.bio)
                        .font(.gilroy(.regular, size: 11))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 2)
                }
            }
            .padding(.top, 2)

            Spacer(minLength: 4)

            if let connectState {
                DiscoverConnectPill(state: connectState, action: { onConnect?() }, onWithdraw: onWithdraw, onDisconnect: onDisconnect)
            } else if !isSelecting {
                HStack(spacing: 10) {
                    circularLink(icon: "phone.fill") {
                        if let url = URL(string: "tel:\(contact.phone.replacingOccurrences(of: " ", with: ""))") {
                            openURL(url)
                        }
                    }

                    circularLink(icon: "envelope.fill") {
                        if let url = URL(string: "mailto:\(contact.email)") {
                            openURL(url)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .frame(height: isLast ? 146 - stackOverlap : 134, alignment: .top)
        .background {
            ZStack {
                metallicBackground
                grainAndSheen
            }
        }
        .environment(\.colorScheme, .light)
        .clipShape(cardShape)
        .overlay(edgeStroke)
        .overlay(
            cardShape
                .strokeBorder(
                    isSelected ? Color.white.opacity(0.95) : .clear,
                    lineWidth: 2
                )
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.55), radius: 22, y: 14)
        .shadow(
            color: (contact.theme.gradientColors.first ?? .purple).opacity(0.35),
            radius: 18, y: 10
        )
    }

    private func circularLink(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.gilroy(.semiBold, size: 18))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: Circle())
    }

    private var metallicBackground: some View {
        ZStack {
            contact.theme.gradientColors.first ?? .purple

            RadialGradient(
                colors: [
                    (contact.theme.gradientColors.first ?? .purple).opacity(0.0),
                    (contact.theme.gradientColors.first ?? .purple).opacity(0.9),
                    (contact.theme.gradientColors.dropFirst().first ?? .purple)
                ],
                center: UnitPoint(x: 0.25, y: 0.0),
                startRadius: 20,
                endRadius: 260
            )

            RadialGradient(
                colors: [
                    (contact.theme.gradientColors.last ?? .orange).opacity(0.95),
                    (contact.theme.gradientColors.last ?? .orange).opacity(0.35),
                    .clear
                ],
                center: UnitPoint(x: 0.85, y: 0.95),
                startRadius: 0,
                endRadius: 200
            )
            .blendMode(.plusLighter)
            .opacity(0.85)

            RadialGradient(
                colors: [.white.opacity(0.32), .white.opacity(0.06), .clear],
                center: UnitPoint(x: 0.12, y: 0.05),
                startRadius: 0,
                endRadius: 160
            )
            .blendMode(.plusLighter)
        }
    }

    private var grainAndSheen: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.10), location: 0.0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.18), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.18), location: 0.0),
                    .init(color: .clear, location: 0.5),
                    .init(color: .white.opacity(0.06), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .blendMode(.softLight)
        }
    }

    private var edgeStroke: some View {
        cardShape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.65),
                        .white.opacity(0.18),
                        .white.opacity(0.08),
                        .white.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.0
            )
    }
}

// MARK: - GlassContactRow (neutral glass, spaced list)

/// Pro members get the signature indigo gradient card (same look as
/// GroupCardView); free members keep the plain glass row.
private struct ContactCardChrome: ViewModifier {
    let isPremium: Bool
    var cornerRadius: CGFloat = 26

    func body(content: Content) -> some View {
        if isPremium {
            content.gradientCard(accent: .indigo, cornerRadius: cornerRadius)
        } else {
            content
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        }
    }
}

struct GlassContactRow: View {
    let contact: ProfileCard
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var connectState: DiscoverConnectState? = nil
    var onConnect: (() -> Void)? = nil
    var onWithdraw: (() -> Void)? = nil
    var onDisconnect: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL

    private let cornerRadius: CGFloat = 26

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// "Job Role - Company", dropping whichever side is empty.
    private var roleLine: String {
        switch (contact.jobRole.isEmpty, contact.companyName.isEmpty) {
        case (false, false): return "\(contact.jobRole) - \(contact.companyName)"
        case (false, true):  return contact.jobRole
        case (true, false):  return contact.companyName
        default:             return ""
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            card
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelecting)
    }

    private var card: some View {
        HStack(alignment: .center, spacing: 14) {
            // Avatar and Pro pill stacked as one unit so the row centers
            // (avatar + badge) together, keeping top/bottom space equal.
            VStack(spacing: -3) {
                Image(contact.avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)

                if contact.isPremiumUser {
                    ProBadge(height: 14)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                // Long names (e.g. "Shubham Khandelwal") wrap to a second
                // line instead of truncating.
                Text(contact.name)
                    .font(.gilroy(.semiBold, size: 19))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !roleLine.isEmpty {
                    Text(roleLine.uppercased())
                        .font(.gilroy(.semiBold, size: 11))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !contact.bio.isEmpty {
                    Text(contact.bio)
                        .font(.gilroy(.regular, size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 4)

            if let connectState {
                DiscoverConnectPill(state: connectState, action: { onConnect?() }, onWithdraw: onWithdraw, onDisconnect: onDisconnect)
            } else if !isSelecting {
                HStack(spacing: 10) {
                    glassCircleButton(icon: "phone.fill") {
                        if let url = URL(string: "tel:\(contact.phone.replacingOccurrences(of: " ", with: ""))") {
                            openURL(url)
                        }
                    }

                    glassCircleButton(icon: "envelope.fill") {
                        if let url = URL(string: "mailto:\(contact.email)") {
                            openURL(url)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(ContactCardChrome(isPremium: contact.isPremiumUser, cornerRadius: cornerRadius))
        .overlay(
            cardShape
                .strokeBorder(
                    isSelected ? Color.white.opacity(0.9) : .clear,
                    lineWidth: 2
                )
        )
    }

    private func glassCircleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.gilroy(.semiBold, size: 18))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(Color.white.opacity(0.10))
                )
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .glassEffect(.clear.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContactsView()
        .environment(ContactsViewModel())
        .environment(UserProfileViewModel())
        .environment(SubscriptionManager())
        .environment(DeviceContactsViewModel())
        .environment(ContactRequestViewModel())
}
