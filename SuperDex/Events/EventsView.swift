//
//  EventsView.swift
//  SuperDex
//
//  Browse events aggregated from Luma, Ticketmaster, Eventbrite,
//  SeatGeek and Meetup, filterable by category, city and platform.
//
//  EventsView is the standalone tab version (owns its NavigationStack);
//  EventsScreen is the pushable content, also used from HomeView's
//  "See all" with a back button.
//

import SwiftUI

struct EventsView: View {
    @State private var viewModel = EventsViewModel()

    var body: some View {
        NavigationStack {
            EventsScreen(viewModel: viewModel)
        }
    }
}

struct EventsScreen: View {
    let viewModel: EventsViewModel
    var showsBackButton = false

    @Environment(UserProfileViewModel.self) private var profileVM
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEvent: AppEvent?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The chips and city/platform filters, then the search on top.
    private var visibleEvents: [AppEvent] {
        guard !trimmedQuery.isEmpty else { return viewModel.filteredEvents }
        return viewModel.filteredEvents.filter { $0.matches(trimmedQuery) }
    }

    var body: some View {
        ZStack {
            AppBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    navBar
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    searchBar
                        .padding(.horizontal, 16)

                    categoryChips

                    cityFilterRow

                    if viewModel.usingSampleData {
                        sampleDataBanner
                            .padding(.horizontal, 22)
                    }

                    eventsList
                        .padding(.horizontal, 20)
                        .padding(.bottom, 56)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                await viewModel.load()
            }

            if viewModel.isLoading && viewModel.events.isEmpty {
                loadingState
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .task {
            RegisteredEventsStore.shared.activate(userId: profileVM.currentUserId)
            await viewModel.loadIfNeeded()

            // The server owns registered marks; replace the local
            // cache with its rows (covers reinstalls, new devices and
            // account switches on the same device).
            if let userId = profileVM.currentUserId,
               let serverIds = await EventRegistrationService()
                   .fetchRegisteredEventIds(userId: userId) {
                RegisteredEventsStore.shared.syncServerIds(serverIds)
            }
        }
    }

    // MARK: - Nav bar (chevron left, title centered inline)

    private var navBar: some View {
        ZStack {
            Text("Events")
                .font(.gilroy(.bold, size: 20))
                .foregroundStyle(.white)

            HStack {
                if showsBackButton {
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
                }

                Spacer()
            }
        }
    }

    // MARK: - Search

    /// Same look as the Deck tab's search bar.
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            TextField(
                "",
                text: $searchText,
                prompt: Text("Search events, venues, cities")
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

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    color: Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0),
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectedCategory = nil
                }

                ForEach(viewModel.availableCategories) { category in
                    filterChip(
                        title: category.displayName,
                        icon: category.icon,
                        color: category.color,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory =
                            viewModel.selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private func filterChip(
        title: String,
        icon: String,
        color: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.gilroy(.semiBold, size: 13))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isSelected ? color.opacity(0.45) : Color.white.opacity(0.06))
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? color.opacity(0.9) : Color.white.opacity(0.14),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - City + platform filters

    private var cityFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                cityMenu
                platformMenu

                Text("\(viewModel.filteredEvents.count) event\(viewModel.filteredEvents.count == 1 ? "" : "s")")
                    .font(.gilroy(.medium, size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 22)
        }
    }

    private var cityMenu: some View {
        Menu {
            Button {
                viewModel.selectedCity = nil
            } label: {
                Label("All Cities", systemImage: "globe")
            }

            Divider()

            ForEach(viewModel.cities, id: \.self) { city in
                Button {
                    viewModel.selectedCity = city
                } label: {
                    if viewModel.selectedCity == city {
                        Label(city, systemImage: "checkmark")
                    } else {
                        Text(city)
                    }
                }
            }
        } label: {
            filterMenuLabel(
                icon: "mappin.and.ellipse",
                iconColor: Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0),
                title: viewModel.selectedCity ?? "All Cities"
            )
        }
        .buttonStyle(.plain)
    }

    private var platformMenu: some View {
        Menu {
            Button {
                viewModel.selectedSource = nil
            } label: {
                Label("All Platforms", systemImage: "globe")
            }

            Divider()

            ForEach(viewModel.availableSources) { source in
                Button {
                    viewModel.selectedSource = source
                } label: {
                    if viewModel.selectedSource == source {
                        Label(source.displayName, systemImage: "checkmark")
                    } else {
                        Label(source.displayName, systemImage: source.icon)
                    }
                }
            }
        } label: {
            filterMenuLabel(
                icon: viewModel.selectedSource?.icon ?? "globe",
                iconColor: viewModel.selectedSource?.brandColor
                    ?? Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0),
                title: viewModel.selectedSource?.displayName ?? "All Platforms"
            )
        }
        .buttonStyle(.plain)
    }

    private func filterMenuLabel(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.gilroy(.semiBold, size: 14))
                .foregroundStyle(.white)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    // MARK: - Sample data banner

    private var sampleDataBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.yellow.opacity(0.9))

            Text("Couldn't reach the event sites right now. Showing sample events — pull down to retry.")
                .font(.gilroy(.medium, size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.yellow.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.yellow.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Events list

    @ViewBuilder
    private var eventsList: some View {
        if visibleEvents.isEmpty && !viewModel.isLoading {
            emptyState
                .padding(.top, 30)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(visibleEvents) { event in
                    Button {
                        selectedEvent = event
                    } label: {
                        EventCardView(event: event)
                    }
                    .buttonStyle(GroupCardPressStyle())
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Text(trimmedQuery.isEmpty ? "No events found" : "No events match \"\(trimmedQuery)\"")
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(trimmedQuery.isEmpty
                 ? "Try a different category, city or platform, or pull down to refresh."
                 : "Try another word, or set the category, city and platform filters to All.")
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.white)
            Text("Finding events…")
                .font(.gilroy(.medium, size: 14))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

#Preview {
    EventsView()
        .environment(UserProfileViewModel())
        .environment(SubscriptionManager())
        .preferredColorScheme(.dark)
}
