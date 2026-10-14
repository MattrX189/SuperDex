//
//  DiscoverView.swift
//  SuperDex
//
//  Discover is an overview page: a Gigs section on top (requirements
//  anyone can post and apply to) and a People section below (Pro
//  member profiles). Each section's "See all" pushes a dedicated
//  page — GigsScreen with gig search/filters, DiscoverPeopleScreen
//  with the full profile browser.
//

import SwiftUI

struct DiscoverView: View {
    @Environment(DiscoverViewModel.self) private var viewModel
    @Environment(UserProfileViewModel.self) private var profileVM
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(ContactRequestViewModel.self) private var contactRequestVM
    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(BlockStore.self) private var blockStore

    @State private var gigsVM = GigsViewModel()
    @State private var selectedGig: GigPost?
    @State private var selectedProfile: ProfileCard?
    @State private var showViewersSheet = false
    @State private var showRequestsSheet = false
    @State private var showAllGigs = false
    @State private var showsDiscoverInfo = false
    @State private var showAllPeople = false
    @Namespace private var profileNamespace

    private var isPremium: Bool {
        subscription.isPro || profileVM.profile.hasPro
    }

    /// First few gigs for the overview (blocked users hidden).
    private var previewGigs: [GigPost] {
        Array(gigsVM.posts.filter { !blockStore.isBlocked($0.userId) }.prefix(2))
    }

    /// First few profiles for the overview (blocked users hidden).
    private var previewProfiles: [DiscoverProfile] {
        Array(viewModel.profiles.filter { !blockStore.isBlocked($0.card.contactUserId) }.prefix(4))
    }

    /// People you're connected with open on their saved-contact page, the
    /// same one Contacts shows (Interactions, How you know).
    @ViewBuilder
    private func profileDetail(for card: ProfileCard) -> some View {
        if let contact = contactsVM.savedContact(for: card) {
            ProfileDetailView(profile: contact.asProfileCard)
        } else {
            ProfileDetailView(profile: card, isDiscovery: true)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    gigsSection
                        .padding(.top, 28)

                    peopleSection
                        .padding(.top, 34)
                        .padding(.bottom, 48)
                }
            }
            .reportsTopScroll()
            .refreshable {
                await viewModel.refresh()
                await gigsVM.refresh()
                await viewModel.loadViewers()
                await contactRequestVM.refresh()
            }
            .task {
                await viewModel.loadViewers()
                await contactRequestVM.refresh()
                await gigsVM.loadIfNeeded(userId: viewModel.currentUserId ?? profileVM.currentUserId)
            }
            .background(AppBackground())
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedProfile) { card in
                profileDetail(for: card)
                    .navigationTransition(.zoom(sourceID: card.id, in: profileNamespace))
            }
            .navigationDestination(item: $selectedGig) { post in
                GigDetailView(post: post, viewModel: gigsVM)
            }
            .navigationDestination(isPresented: $showAllGigs) {
                GigsScreen(viewModel: gigsVM)
            }
            .navigationDestination(isPresented: $showAllPeople) {
                DiscoverPeopleScreen()
            }
            .sheet(isPresented: $showViewersSheet) {
                ProfileViewersSheet()
            }
            .sheet(isPresented: $showRequestsSheet) {
                PendingRequestsSheet()
            }
            .sheet(isPresented: $showsDiscoverInfo) {
                DiscoverInfoSheet(gigsVM: gigsVM)
            }
        }
    }

    // MARK: - Connect state (for the People preview rows)

    private func connectState(for profile: DiscoverProfile) -> DiscoverConnectState {
        guard let contactUserId = profile.card.contactUserId else { return .connect }
        if contactsVM.contactExists(contactUserId: contactUserId) { return .connected }
        switch contactRequestVM.sentStatuses[contactUserId] {
        case .pending:       return .pending
        case .accepted:      return .connected
        case .rejected, nil: return .connect
        }
    }

    private func sendConnect(_ profile: DiscoverProfile) {
        guard let contactUserId = profile.card.contactUserId else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { await contactRequestVM.sendRequest(to: contactUserId) }
    }

    private func withdrawConnect(_ profile: DiscoverProfile) {
        guard let contactUserId = profile.card.contactUserId else { return }
        Task { await contactRequestVM.withdrawRequest(to: contactUserId) }
    }

    private func disconnect(_ profile: DiscoverProfile) {
        guard let contactUserId = profile.card.contactUserId else { return }
        Task {
            await contactRequestVM.disconnect(from: contactUserId)
            await contactsVM.refresh()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Image(isPremium ? "SuperDexProText" : "SuperDexText")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 14)

                HStack(alignment: .center, spacing: 10) {
                    Text("Discover")
                        .font(.gilroy(.bold, size: 42))
                        .foregroundStyle(.white)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showsDiscoverInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("About Discover")
                }
            }

            Spacer()

            menuButton
                .padding(.top, 16)
        }
    }

    private var menuButton: some View {
        Menu {
            Button {
                showViewersSheet = true
            } label: {
                Label(
                    viewModel.viewerCount > 0 ? "Profile Views (\(viewModel.viewerCount))" : "Profile Views",
                    systemImage: "eye.fill"
                )
            }

            Button {
                showRequestsSheet = true
            } label: {
                Label(
                    contactRequestVM.pendingCount > 0 ? "Connect Requests (\(contactRequestVM.pendingCount))" : "Connect Requests",
                    systemImage: "bell.fill"
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .glassEffect(.clear.interactive(), in: Circle())
                .overlay(alignment: .topTrailing) {
                    if contactRequestVM.pendingCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .accessibilityLabel("Discover options")
    }

    // MARK: - Section header

    // Mirrors HomeView's sectionHeader so Discover reads like Home.
    private func sectionHeader(
        _ title: String,
        onSeeAll: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.gilroy(.bold, size: 20))
                .foregroundStyle(.white)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSeeAll()
            } label: {
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
        .padding(.horizontal, 20)
    }

    // MARK: - Gigs section

    private var gigsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Opportunities") {
                showAllGigs = true
            }

            if gigsVM.isLoading && gigsVM.posts.isEmpty {
                sectionLoadingRow("Finding opportunities…")
            } else if previewGigs.isEmpty {
                sectionEmptyCard(
                    icon: "briefcase",
                    text: gigsVM.loadFailed
                        ? "Couldn't load opportunities. Pull to refresh."
                        : "No opportunities yet — post the first requirement."
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(previewGigs) { post in
                        GigCardView(
                            post: post,
                            isOwn: post.isOwn(gigsVM.currentUserId)
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedGig = post
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - People section

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("People") {
                showAllPeople = true
            }

            if viewModel.isLoading && viewModel.profiles.isEmpty {
                sectionLoadingRow("Finding Pro members…")
            } else if previewProfiles.isEmpty {
                sectionEmptyCard(
                    icon: "sparkles",
                    text: "Pro members will appear here as people upgrade."
                )
            } else {
                LazyVStack(spacing: 18) {
                    ForEach(previewProfiles) { profile in
                        GlassContactRow(
                            contact: profile.card,
                            connectState: connectState(for: profile),
                            onConnect: { sendConnect(profile) },
                            onWithdraw: { withdrawConnect(profile) },
                            onDisconnect: { disconnect(profile) }
                        )
                        .matchedTransitionSource(id: profile.card.id, in: profileNamespace)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedProfile = profile.card
                            viewModel.recordView(of: profile.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Small shared states

    private func sectionLoadingRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().tint(.white.opacity(0.7))
            Text(text)
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    private func sectionEmptyCard(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.35))

            Text(text)
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Dedicated People page ("See all")

struct DiscoverPeopleScreen: View {
    @Environment(DiscoverViewModel.self) private var viewModel
    @Environment(ContactRequestViewModel.self) private var contactRequestVM
    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(BlockStore.self) private var blockStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage("discoverLayoutStyle") private var layoutStyle: ContactsLayoutStyle = .glass
    @State private var searchText: String = ""
    @State private var selectedCategory: ProfileCategory? = nil
    @State private var selectedProfile: ProfileCard?
    @FocusState private var isSearchFocused: Bool
    @Namespace private var profileNamespace

    // Deck-fan overscroll physics (matches ContactsView)
    @State private var pullStretch: CGFloat = 0
    @State private var hasTriggeredStretchHaptic = false

    private var profiles: [DiscoverProfile] { viewModel.profiles }

    private var filteredProfiles: [DiscoverProfile] {
        // Blocked users are hidden from the feed instantly (Guideline 1.2).
        var result = profiles.filter { !blockStore.isBlocked($0.card.contactUserId) }

        if let category = selectedCategory {
            result = result.filter { $0.card.categories.contains(category) }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result }
        let digitsQuery = query.filter(\.isNumber)
        return result.filter { profile in
            let card = profile.card
            if card.name.localizedCaseInsensitiveContains(query) { return true }
            if card.jobRole.localizedCaseInsensitiveContains(query) { return true }
            if card.companyName.localizedCaseInsensitiveContains(query) { return true }
            if card.email.localizedCaseInsensitiveContains(query) { return true }
            if card.username.localizedCaseInsensitiveContains(query) { return true }
            if card.phone.localizedCaseInsensitiveContains(query) { return true }
            if !digitsQuery.isEmpty {
                let phoneDigits = card.phone.filter(\.isNumber)
                if phoneDigits.contains(digitsQuery) { return true }
            }
            return false
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// People you're connected with open on their saved-contact page, the
    /// same one Contacts shows (Interactions, How you know).
    @ViewBuilder
    private func profileDetail(for card: ProfileCard) -> some View {
        if let contact = contactsVM.savedContact(for: card) {
            ProfileDetailView(profile: contact.asProfileCard)
        } else {
            ProfileDetailView(profile: card, isDiscovery: true)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    navBar
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    categoryChips
                        .padding(.bottom, 18)

                    if viewModel.isLoading && profiles.isEmpty {
                        loadingState
                            .padding(.top, 80)
                    } else if profiles.isEmpty {
                        emptyState
                            .padding(.top, 80)
                    } else if filteredProfiles.isEmpty {
                        noResultsState
                            .padding(.top, 60)
                    } else {
                        profileList
                    }
                }
            }
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
                await viewModel.refresh()
                await contactRequestVM.refresh()
            }
        }
        .navigationBarHidden(true)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: layoutStyle)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedCategory)
        .navigationDestination(item: $selectedProfile) { card in
            profileDetail(for: card)
                .navigationTransition(.zoom(sourceID: card.id, in: profileNamespace))
        }
    }

    // MARK: - Nav bar (chevron left, title centered, layout toggle right)

    private var navBar: some View {
        ZStack {
            Text("People")
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        layoutStyle.toggle()
                    }
                } label: {
                    Image(systemName: layoutStyle == .color ? "square.stack.3d.up.fill" : "rectangle.stack.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Toggle layout style")
            }
        }
    }

    // MARK: - Connect state

    private func connectState(for profile: DiscoverProfile) -> DiscoverConnectState {
        guard let contactUserId = profile.card.contactUserId else { return .connect }
        if contactsVM.contactExists(contactUserId: contactUserId) { return .connected }
        switch contactRequestVM.sentStatuses[contactUserId] {
        case .pending:       return .pending
        case .accepted:      return .connected
        case .rejected, nil: return .connect
        }
    }

    private func sendConnect(_ profile: DiscoverProfile) {
        guard let contactUserId = profile.card.contactUserId else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task { await contactRequestVM.sendRequest(to: contactUserId) }
    }

    private func withdrawConnect(_ profile: DiscoverProfile) {
        guard let contactUserId = profile.card.contactUserId else { return }
        Task { await contactRequestVM.withdrawRequest(to: contactUserId) }
    }

    private func disconnect(_ profile: DiscoverProfile) {
        guard let contactUserId = profile.card.contactUserId else { return }
        Task {
            await contactRequestVM.disconnect(from: contactUserId)
            await contactsVM.refresh()
        }
    }

    // MARK: - Profile list

    @ViewBuilder
    private var profileList: some View {
        switch layoutStyle {
        case .color:
            LazyVStack(spacing: -40) {
                ForEach(Array(filteredProfiles.enumerated()), id: \.element.id) { index, profile in
                    ColorContactRow(
                        contact: profile.card,
                        isLast: index == filteredProfiles.count - 1,
                        connectState: connectState(for: profile),
                        onConnect: { sendConnect(profile) },
                        onWithdraw: { withdrawConnect(profile) },
                            onDisconnect: { disconnect(profile) }
                    )
                    .matchedTransitionSource(id: profile.card.id, in: profileNamespace)
                    .modifier(
                        DiscoverDeckPhysics(
                            index: index,
                            stretch: pullStretch
                        )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedProfile = profile.card
                        viewModel.recordView(of: profile.id)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)

        case .glass:
            LazyVStack(spacing: 18) {
                ForEach(filteredProfiles) { profile in
                    GlassContactRow(
                        contact: profile.card,
                        connectState: connectState(for: profile),
                        onConnect: { sendConnect(profile) },
                        onWithdraw: { withdrawConnect(profile) },
                            onDisconnect: { disconnect(profile) }
                    )
                        .matchedTransitionSource(id: profile.card.id, in: profileNamespace)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedProfile = profile.card
                            viewModel.recordView(of: profile.id)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
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
                prompt: Text("Search Pro members by name, role, company")
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
        .onTapGesture { isSearchFocused = true }
    }

    // MARK: - Category chips

    private var categoryChips: some View {
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

    // MARK: - Empty / loading / no-results states

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white.opacity(0.7))
            Text("Finding Pro members…")
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.gilroy(.regular, size: 44))
                .foregroundStyle(.white.opacity(0.35))

            Text("No Pro members yet")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))

            Text("Pro members will appear here as people upgrade.")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
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
                Text("No \(category.displayName) match \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\".")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else if let category = selectedCategory {
                Text("No Pro members found in \(category.displayName).")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else {
                Text("No Pro members match \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\".")
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

// MARK: - Deck physics (mirror of ContactsView's)

struct DiscoverDeckPhysics: ViewModifier {
    let index: Int
    let stretch: CGFloat

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

#Preview {
    DiscoverView()
        .environment(DiscoverViewModel())
        .environment(UserProfileViewModel())
        .environment(SubscriptionManager())
        .environment(BlockStore())
        .environment(ContactRequestViewModel())
        .environment(ContactsViewModel())
        .preferredColorScheme(.dark)
}
