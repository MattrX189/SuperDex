//
//  UpcomingEventsSection.swift
//  SuperDex
//
//  "Upcoming events" block: title (links to the full Events page),
//  platform menu, city chips and the this-week carousel. Shared by
//  Home and Deck; filters live on the shared EventsViewModel so both
//  screens stay in sync. Deck passes a footer ("Create deck").
//

import SwiftUI

struct UpcomingEventsSection<Route: Hashable, Footer: View>: View {
    let viewModel: EventsViewModel
    /// Pushed when the title is tapped; the host registers its destination.
    let allEventsRoute: Route
    var title: String = "Upcoming events"
    var subtitle: String = "Happening this week"
    @ViewBuilder var footer: (AppEvent) -> Footer

    private let accentIndigo = Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0)

    private var carouselEvents: [AppEvent] {
        Array(viewModel.eventsThisWeek.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                NavigationLink(value: allEventsRoute) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.gilroy(.bold, size: 28))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .foregroundStyle(.white)

                        Text(subtitle)
                            .font(.gilroy(.medium, size: 15))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                sourceMenu
            }
            .padding(.horizontal, 20)

            cityFilterChips

            if viewModel.isLoading && viewModel.events.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
                .padding(.vertical, 28)
            } else if carouselEvents.isEmpty {
                noNearbyEventsCard
                    .padding(.horizontal, 20)
            } else {
                EventsCarousel(events: carouselEvents, footer: footer)
            }
        }
    }

    private var sourceMenu: some View {
        Menu {
            menuOption("All Platforms", isSelected: viewModel.selectedSource == nil) {
                viewModel.selectedSource = nil
            }
            Divider()
            ForEach(viewModel.availableSources) { source in
                menuOption(source.displayName, isSelected: viewModel.selectedSource == source) {
                    viewModel.selectedSource = source
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.selectedSource?.icon ?? "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(viewModel.selectedSource?.brandColor ?? accentIndigo)
                Text(viewModel.selectedSource?.displayName ?? "All")
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var cityFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                cityChip("All Cities", icon: "mappin.and.ellipse", isSelected: viewModel.selectedCity == nil) {
                    viewModel.selectedCity = nil
                }
                ForEach(viewModel.cities, id: \.self) { city in
                    cityChip(city, isSelected: viewModel.selectedCity == city) {
                        viewModel.selectedCity = city
                    }
                }
            }
        }
        .safeAreaPadding(.horizontal, 20)
        .scrollClipDisabled()
    }

    private func cityChip(
        _ title: String,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.gilroy(.semiBold, size: 13))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(isSelected ? Color.white : Color.clear))
            .glassEffect(isSelected ? .identity : .regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func menuOption(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var noNearbyEventsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Text("No events this week match these filters.")
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

extension UpcomingEventsSection where Footer == EmptyView {
    init(viewModel: EventsViewModel, allEventsRoute: Route, subtitle: String = "Happening this week") {
        self.init(viewModel: viewModel, allEventsRoute: allEventsRoute, subtitle: subtitle) { _ in EmptyView() }
    }
}
