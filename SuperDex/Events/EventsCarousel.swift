//
//  EventsCarousel.swift
//  SuperDex
//
//  Paged carousel of large square event cards that auto-advances in an
//  endless left-to-right loop.
//  Shared by Home ("Upcoming events") and Deck ("Happening this week");
//  `footer` adds per-event content under each card (e.g. Deck's
//  "Create deck" button).
//

import SwiftUI

struct EventsCarousel<Footer: View>: View {
    let events: [AppEvent]
    @ViewBuilder var footer: (AppEvent) -> Footer

    /// Index into `slots`. The events are laid out three times over so the
    /// carousel can keep moving right forever: whenever it settles in the
    /// first or last copy it jumps, unanimated, to the same card in the
    /// middle copy.
    @State private var position: Int?
    @State private var lastInteraction = Date.distantPast

    private var copies: Int { events.count > 1 ? 3 : 1 }
    private var slotCount: Int { events.count * copies }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Top-aligned: titles wrap to different heights.
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(0..<slotCount, id: \.self) { slot in
                    let event = events[slot % events.count]
                    VStack(spacing: 14) {
                        NavigationLink(value: event) {
                            EventSquareCard(event: event)
                        }
                        .buttonStyle(GroupCardPressStyle())

                        footer(event)
                    }
                    .containerRelativeFrame(.horizontal)
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.88)
                            .opacity(phase.isIdentity ? 1 : 0.5)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position)
        .safeAreaPadding(.horizontal, 40)
        .scrollClipDisabled()
        .onScrollPhaseChange { _, phase in
            if phase == .interacting || phase == .tracking {
                lastInteraction = .now
            }
            if phase == .idle {
                recenter()
            }
        }
        .task(id: events.map(\.id)) {
            jump(to: copies > 1 ? events.count : 0)
            await autoScroll()
        }
    }

    /// Advances one card every few seconds, always left → right, looping
    /// endlessly. Pauses briefly after the user swipes the carousel themselves.
    private func autoScroll() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            guard events.count > 1,
                  Date.now.timeIntervalSince(lastInteraction) > 5 else { continue }
            recenter()
            let next = min((position ?? events.count) + 1, slotCount - 1)
            withAnimation(.smooth(duration: 0.6)) {
                position = next
            }
        }
    }

    /// Moves from the outer copies back to the identical card in the middle
    /// copy, so there's always room to keep scrolling either way.
    private func recenter() {
        guard copies > 1, let position else { return }
        let count = events.count
        if position < count || position >= 2 * count {
            jump(to: count + position % count)
        }
    }

    private func jump(to slot: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { position = slot }
    }
}

extension EventsCarousel where Footer == EmptyView {
    init(events: [AppEvent]) {
        self.init(events: events) { _ in EmptyView() }
    }
}

/// Square image card with category + registered badges, title and
/// date/venue line underneath.
struct EventSquareCard: View {
    let event: AppEvent

    /// Whether the image is light where the category chip sits, so the
    /// chip can switch to dark text (white text vanishes on white posters).
    @State private var chipOnLight = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)

        VStack(spacing: 14) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let url = event.imageURL {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            placeholder
                        }
                    } else {
                        placeholder
                    }
                }
                .clipShape(shape)
                .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 8) {
                        Image(systemName: event.category.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(event.category.displayName)
                            .font(.gilroy(.semiBold, size: 15))
                    }
                    .foregroundStyle(chipOnLight ? .black : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassEffect(.clear, in: Capsule())
                    .padding(14)
                    .animation(.easeOut(duration: 0.2), value: chipOnLight)
                }
                .overlay(alignment: .topTrailing) {
                    if RegisteredEventsStore.shared.isRegistered(event.id) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.green)
                            .frame(width: 36, height: 36)
                            .glassEffect(.clear, in: Circle())
                            .padding(14)
                    }
                }
                .shadow(color: .black.opacity(0.45), radius: 18, y: 10)

            // Title, then where, then when — one line each.
            VStack(spacing: 6) {
                // Full title, wrapping as needed — never cut off.
                Text(event.title)
                    .font(.gilroy(.bold, size: 20))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                detailLine(icon: "mappin.and.ellipse", text: locationLine)
                if let dateLine {
                    detailLine(icon: "calendar", text: dateLine)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .task(id: event.imageURL) {
            guard let url = event.imageURL,
                  let image = await ImageCache.shared.load(url) else {
                chipOnLight = false  // placeholder gradient is dark
                return
            }
            chipOnLight = ImageTone.isLight(url: url, image: image, chipRegion: Self.chipRegion)
        }
    }

    /// Where the category chip sits, as a fraction of the square (the image
    /// is scaledToFill, so this is relative to its centered square crop).
    private static let chipRegion = CGRect(x: 0.03, y: 0.03, width: 0.5, height: 0.14)

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [event.category.color.opacity(0.7), Color(red: 0.06, green: 0.07, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: event.category.icon)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func detailLine(icon: String, text: String) -> some View {
        // Long venues wrap to a second line instead of being cut off.
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.gilroy(.medium, size: 14))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white.opacity(0.6))
    }

    /// "Venue, City", or just the city.
    private var locationLine: String {
        let venue = event.venue?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !venue.isEmpty else { return event.city }
        return venue.localizedCaseInsensitiveContains(event.city) ? venue : "\(venue), \(event.city)"
    }

    /// "Thu, Oct 15 at 4:30 PM"
    private var dateLine: String? {
        event.startDate?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }
}

// MARK: - Image tone

/// Average brightness of part of an image, to pick legible overlay text.
@MainActor
enum ImageTone {
    private static var cache: [String: Bool] = [:]

    /// `chipRegion` is normalized to the image's centered square crop.
    static func isLight(url: URL, image: UIImage, chipRegion: CGRect) -> Bool {
        let key = "\(url.absoluteString)|\(chipRegion.debugDescription)"
        if let cached = cache[key] { return cached }

        guard let cgImage = image.cgImage else { return false }
        let side = CGFloat(min(cgImage.width, cgImage.height))
        let origin = CGPoint(
            x: (CGFloat(cgImage.width) - side) / 2,
            y: (CGFloat(cgImage.height) - side) / 2
        )
        let crop = CGRect(
            x: origin.x + chipRegion.minX * side,
            y: origin.y + chipRegion.minY * side,
            width: chipRegion.width * side,
            height: chipRegion.height * side
        ).integral

        guard let region = cgImage.cropping(to: crop) else { return false }

        // Average by drawing the region into an 8×8 bitmap.
        let size = 8
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.interpolationQuality = .medium
        context.draw(region, in: CGRect(x: 0, y: 0, width: size, height: size))

        var total: Double = 0
        for pixel in 0..<(size * size) {
            let r = Double(pixels[pixel * 4]) / 255
            let g = Double(pixels[pixel * 4 + 1]) / 255
            let b = Double(pixels[pixel * 4 + 2]) / 255
            total += 0.2126 * r + 0.7152 * g + 0.0722 * b
        }
        let isLight = total / Double(size * size) > 0.6
        cache[key] = isLight
        return isLight
    }
}
