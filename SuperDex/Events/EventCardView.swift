//
//  EventCardView.swift
//  SuperDex
//
//  Event row card, styled to match GroupCardView, with a badge
//  showing which website the event is listed on.
//

import SwiftUI

struct EventCardView: View {
    let event: AppEvent

    private let cornerRadius: CGFloat = 26
    private var accent: Color { .indigo }

    var body: some View {
        HStack(spacing: 16) {
            leadingBadge

            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.gilroy(.bold, size: 16))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let date = event.startDate {
                        metaLabel(icon: "calendar", text: shortDateString(date))
                    }
                    metaLabel(icon: "mappin.and.ellipse", text: event.city)
                }

                HStack(spacing: 6) {
                    sourceChip

                    if RegisteredEventsStore.shared.isRegistered(event.id) {
                        registeredChip
                    }
                }
            }

            Spacer(minLength: 8)

            chevronCapsule
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 104)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .compositingGroup()
        .overlay(highlightBorder)
        .shadow(color: accent.opacity(0.30), radius: 18, y: 12)
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Leading badge

    @ViewBuilder
    private var leadingBadge: some View {
        if let imageURL = event.thumbnailURL {
            CachedAsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                iconBadgeContent
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.40), radius: 8, y: 4)
        } else {
            iconBadge
        }
    }

    private var iconBadge: some View {
        iconBadgeContent
            .frame(width: 56, height: 56)
            .shadow(color: accent.opacity(0.55), radius: 10, y: 6)
    }

    private var iconBadgeContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent,
                            accent.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)

            Image(systemName: event.category.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
    }

    // MARK: - Meta

    private func metaLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(text)
                .font(.gilroy(.medium, size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
    }

    private var sourceChip: some View {
        HStack(spacing: 5) {
            Image(systemName: event.source.icon)
                .font(.system(size: 9, weight: .bold))
            Text(event.source.displayName)
                .font(.gilroy(.semiBold, size: 10))
                .tracking(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(accent.opacity(0.35))
        )
        .overlay(
            Capsule().strokeBorder(accent.opacity(0.7), lineWidth: 1)
        )
    }

    private var registeredChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 9, weight: .bold))
            Text("Registered")
                .font(.gilroy(.semiBold, size: 10))
                .tracking(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.green.opacity(0.30))
        )
        .overlay(
            Capsule().strokeBorder(Color.green.opacity(0.65), lineWidth: 1)
        )
    }

    // MARK: - Chevron

    private var chevronCapsule: some View {
        Image(systemName: "chevron.right")
            .font(.gilroy(.semiBold, size: 12))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
    }

    // MARK: - Background

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.06, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [accent.opacity(0.40), .clear],
                center: UnitPoint(x: 0.0, y: 0.0),
                startRadius: 0,
                endRadius: 240
            )

            RadialGradient(
                colors: [accent.opacity(0.20), .clear],
                center: UnitPoint(x: 1.0, y: 1.1),
                startRadius: 0,
                endRadius: 200
            )

            RadialGradient(
                colors: [.white.opacity(0.10), .clear],
                center: UnitPoint(x: 0.95, y: 0.05),
                startRadius: 0,
                endRadius: 180
            )
        }
    }

    private var highlightBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        accent.opacity(0.55),
                        .white.opacity(0.10),
                        .clear,
                        accent.opacity(0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            ForEach(SampleEvents.make().prefix(4)) { event in
                EventCardView(event: event)
            }
        }
        .padding(20)
    }
    .preferredColorScheme(.dark)
}
