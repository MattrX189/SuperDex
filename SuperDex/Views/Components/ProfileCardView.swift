//
//  ProfileCardView.swift
//  HomeScreen
//

import SwiftUI
import UIKit

struct ProfileCardView: View {
    let profile: ProfileCard
    var username: String? = nil
    var showsActions: Bool = true
    var showsShadow: Bool = true
    var allowsFlip: Bool = false
    /// Plays one full 360° spin (with haptics) shortly after the card appears.
    var spinOnAppear: Bool = false
    var spinDelay: Double = 0
    /// Show WhatsApp/Instagram/LinkedIn/X even when not filled in — for
    /// previews (e.g. onboarding's theme picker) where the full layout
    /// matters more than the user's data.
    var showsEmptyLinks: Bool = false

    @Environment(\.openURL) private var openURL
    @State private var showQRSheet = false

    // Flip / rotation state
    @State private var rotation: Double = 0          // committed Y rotation in degrees
    @State private var gestureBase: Double = 0       // rotation captured at drag start
    @State private var isDragging = false
    @State private var lastQuarter = 0               // last 90° boundary crossed (for haptics)
    @State private var lastTranslation: CGFloat = 0
    @State private var haptics = FlipHaptics()
    @State private var hasSpun = false

    private let cornerRadius: CGFloat = 32

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// Rotation normalized to 0..<360 to decide which face is toward the viewer.
    private var normalizedRotation: Double {
        let r = rotation.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    private var showsFront: Bool {
        normalizedRotation < 90 || normalizedRotation > 270
    }

    var body: some View {
        flipContainer
            .task { await spinIfNeeded() }
            .sheet(isPresented: $showQRSheet) {
                if let username {
                    // Same as Home → My Card: card page, then the QR grows.
                    ProfileQRSheet(profile: profile, username: username, qrCodeData: profile.qrCodeData, magnifiesOnOpen: true)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
    }

    // MARK: - Flip Container

    private var flipContainer: some View {
        ZStack {
            frontFace
                .opacity(showsFront ? 1 : 0)

            backFace
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsFront ? 0 : 1)
        }
        .rotation3DEffect(
            .degrees(rotation),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: 0.18
        )
        .scaleEffect(isDragging ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isDragging)
        .modifier(FlipGestureModifier(isEnabled: allowsFlip, onChanged: flipChanged, onEnded: flipEnded))
    }

    // MARK: - Flip Gesture

    // A UIKit pan that only begins for horizontal drags. A SwiftUI
    // DragGesture claims vertical drags too, so swiping down on the card
    // couldn't scroll its container or close the sheet it's in.
    private func flipChanged(_ translation: CGFloat) {
        if !isDragging {
            isDragging = true
            gestureBase = rotation
            lastQuarter = Int((rotation / 90).rounded(.down))
            lastTranslation = 0
            haptics.prepare()
        }

        // Horizontal drag drives Y rotation. ~2.4px per degree.
        let newRotation = gestureBase + Double(translation) / 2.4
        rotation = newRotation

        // Speed → haptic intensity
        let delta = translation - lastTranslation
        lastTranslation = translation
        let speed = min(abs(delta) / 14.0, 1.0)
        let intensity = CGFloat(0.45 + speed * 0.55)

        // Fire a tick each time we cross a 90° boundary.
        let quarter = Int((newRotation / 90).rounded(.down))
        if quarter != lastQuarter {
            // Even boundaries (0,180,…) land flat → soft; odd (90,270,…) edge-on → crisp.
            if abs(quarter) % 2 == 0 {
                haptics.tick(intensity: intensity)
            } else {
                haptics.edge(intensity: intensity)
            }
            lastQuarter = quarter
        }
    }

    private func flipEnded(_ translation: CGFloat, _ velocity: CGFloat) {
        guard isDragging else { return }
        isDragging = false

        // Carry momentum, then snap to the nearest face (multiple of 180°).
        // Roughly where SwiftUI's predictedEndTranslation would land.
        let predicted = gestureBase + Double(translation + velocity * 0.2) / 2.4
        let snapped = (predicted / 180).rounded() * 180

        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            rotation = snapped
        }
        haptics.snap()
    }

    // MARK: - Intro Spin

    /// Steps the rotation frame-by-frame (rather than `withAnimation`) so the
    /// front/back face swap and the 90° haptic ticks happen at the right moment.
    private func spinIfNeeded() async {
        guard spinOnAppear, !hasSpun else { return }
        hasSpun = true

        try? await Task.sleep(for: .seconds(spinDelay))
        haptics.prepare()

        let duration = 1.3
        let start = rotation
        let clock = ContinuousClock()
        let began = clock.now
        var quarter = Int((start / 90).rounded(.down))

        while !Task.isCancelled, !isDragging {
            let elapsed = (clock.now - began) / .seconds(1)
            let t = min(elapsed / duration, 1)
            // Ease-in-out cubic
            let eased = t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
            rotation = start + 360 * eased

            let newQuarter = Int((rotation / 90).rounded(.down))
            if newQuarter != quarter, t < 1 {
                let intensity = CGFloat(0.5 + 0.5 * sin(.pi * t))
                if abs(newQuarter) % 2 == 0 {
                    haptics.tick(intensity: intensity)
                } else {
                    haptics.edge(intensity: intensity)
                }
                quarter = newQuarter
            }

            if t >= 1 {
                haptics.snap()
                break
            }
            try? await Task.sleep(for: .milliseconds(8))
        }
    }

    // MARK: - Card Faces

    private var frontFace: some View {
        ZStack {
            metallicBackground
            grainAndSheen
            contentLayer
        }
        .environment(\.colorScheme, .light)
        .clipShape(cardShape)
        .overlay(edgeStroke)
        .compositingGroup()
        .shadow(color: showsShadow ? .black.opacity(0.55) : .clear, radius: 28, y: 16)
        .shadow(
            color: showsShadow ? (profile.theme.gradientColors.first ?? .purple).opacity(0.45) : .clear,
            radius: 22, y: 10
        )
    }

    private var backFace: some View {
        ZStack {
            metallicBackground
            grainAndSheen
            backContent
        }
        .environment(\.colorScheme, .light)
        .clipShape(cardShape)
        .overlay(edgeStroke)
        .compositingGroup()
        .shadow(color: showsShadow ? .black.opacity(0.55) : .clear, radius: 28, y: 16)
        .shadow(
            color: showsShadow ? (profile.theme.gradientColors.first ?? .purple).opacity(0.45) : .clear,
            radius: 22, y: 10
        )
    }

    private var backContent: some View {
        VStack(spacing: 20) {
            Image("iconSD")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 190, height: 190)
                .shadow(color: .black.opacity(0.30), radius: 22, y: 10)

            Image("SuperDexTextHD")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 180)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Metallic Background

    private var metallicBackground: some View {
        ZStack {
            profile.theme.gradientColors.first ?? .purple

            RadialGradient(
                colors: [
                    (profile.theme.gradientColors.first ?? .purple).opacity(0.0),
                    (profile.theme.gradientColors.first ?? .purple).opacity(0.9),
                    (profile.theme.gradientColors.dropFirst().first ?? .purple)
                ],
                center: UnitPoint(x: 0.25, y: 0.0),
                startRadius: 40,
                endRadius: 480
            )

            RadialGradient(
                colors: [
                    (profile.theme.gradientColors.last ?? .orange).opacity(0.95),
                    (profile.theme.gradientColors.last ?? .orange).opacity(0.35),
                    .clear
                ],
                center: UnitPoint(x: 0.8, y: 0.95),
                startRadius: 0,
                endRadius: 320
            )
            .blendMode(.plusLighter)
            .opacity(0.85)

            RadialGradient(
                colors: [.white.opacity(0.35), .white.opacity(0.08), .clear],
                center: UnitPoint(x: 0.15, y: 0.05),
                startRadius: 0,
                endRadius: 220
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
                lineWidth: 1.2
            )
    }

    // MARK: - Content

    private var contentLayer: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                qrButton
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)

            Spacer(minLength: 10)

            avatar

            Spacer().frame(height: 14)

            Text(profile.name)
                .font(.gilroy(.semiBold, size: 26))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            Spacer().frame(height: 8)

            // Role · Company
            Group {
                if !profile.jobRole.isEmpty && !profile.companyName.isEmpty {
                    let combined = "\(profile.jobRole.uppercased())  ·  \(profile.companyName.uppercased())"
                    if profile.bio.isEmpty {
                        // No bio below, so there's room to put the company
                        // on its own line rather than truncating it.
                        ViewThatFits(in: .horizontal) {
                            roleLineText(combined)
                                .fixedSize(horizontal: true, vertical: false)
                            VStack(spacing: 6) {
                                roleLineText(profile.jobRole.uppercased())
                                roleLineText(profile.companyName.uppercased())
                            }
                        }
                    } else {
                        roleLineText(combined)
                    }
                } else if !profile.jobRole.isEmpty {
                    roleLineText(profile.jobRole.uppercased())
                } else if !profile.companyName.isEmpty {
                    roleLineText(profile.companyName.uppercased())
                }
            }
            .padding(.horizontal, 20)

            if !profile.bio.isEmpty {
                Spacer().frame(height: 10)

                CardBioText(bio: profile.bio)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 12)

            if showsActions {
                contactButtons

                Spacer(minLength: 10)

                brandRow
                    .padding(.bottom, 20)
            } else {
                Spacer(minLength: 20)
            }
        }
    }

    private func roleLineText(_ text: String) -> some View {
        Text(text)
            .font(.gilroy(.semiBold, size: 12))
            .tracking(1.6)
            .foregroundStyle(.white.opacity(0.88))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var qrButton: some View {
        if username != nil {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showQRSheet = true
            } label: {
                Image(systemName: "qrcode")
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .glassEffect(.clear.interactive(), in: Circle())
        }
    }

    private var avatar: some View {
        Image(profile.avatar)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 96, height: 96)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    private var contactButtons: some View {
        HStack(spacing: 18) {
            circularLink(
                icon: "phone.fill",
                urlString: "tel:\(profile.phone.replacingOccurrences(of: " ", with: ""))"
            )
            circularLink(
                icon: "envelope.fill",
                urlString: "mailto:\(profile.email)"
            )
        }
    }

    private func circularLink(icon: String, urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) { openURL(url) }
        } label: {
            Image(systemName: icon)
                .font(.gilroy(.semiBold, size: 26))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
        }
        .buttonStyle(.plain)
        .glassEffect(.clear.interactive(), in: Circle())

    }

    private static let mandatoryLinks: [ProfileLink] = [.whatsapp, .instagram, .linkedin, .x]

    private var displayedLinks: [ProfileLinkEntry] {
        if profile.isPremiumUser && !profile.pinnedLinks.isEmpty {
            return profile.pinnedLinks.prefix(kMaxDisplayedLinks).compactMap { key in
                guard let link = ProfileLink(rawValue: key) else { return nil }
                let value = profile.links[key] ?? ""
                guard !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                return ProfileLinkEntry(
                    link: link,
                    value: value,
                    customLabel: link == .customLink ? profile.customLinkTitle : ""
                )
            }
        }
        // Only the networks they've actually filled in.
        return Self.mandatoryLinks.compactMap { link in
            let value = profile.links[link.rawValue] ?? ""
            guard showsEmptyLinks || !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ProfileLinkEntry(link: link, value: value, customLabel: "")
        }
    }

    private var brandRow: some View {
        let links = displayedLinks
        return Group {
            if links.count >= 4 {
                // A full row spreads edge to edge, as before.
                HStack(spacing: 0) {
                    ForEach(Array(links.enumerated()), id: \.element) { index, entry in
                        if index > 0 { Spacer(minLength: 4) }
                        brandLink(entry: entry)
                    }
                }
            } else {
                // Fewer links sit centered; an empty row keeps its height so
                // the rest of the card doesn't shift.
                HStack(spacing: 22) {
                    ForEach(links, id: \.self) { brandLink(entry: $0) }
                }
                .frame(maxWidth: .infinity, minHeight: 46)
            }
        }
        .padding(.horizontal, 20)
    }

    private func brandLink(entry: ProfileLinkEntry) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            if let url = entry.url { openURL(url) }
        } label: {
            Group {
                if let brandName = entry.link.brandIconName {
                    BrandIcon(name: brandName)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: entry.link.fallbackSymbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!entry.value.isEmpty)
        .glassEffect(.clear.interactive(), in: shape)
    }
}

// MARK: - Bio

/// The card's two-line bio. Rather than cutting mid-sentence with "…",
/// it shows as many whole sentences as fit; only a single sentence too
/// long for two lines falls back to truncation. Measured by SwiftUI
/// itself, so it follows the real font and Dynamic Type.
private struct CardBioText: View {
    let bio: String

    var body: some View {
        // Reserve exactly two lines; ViewThatFits picks the longest text
        // that fits in that space.
        styled(Text("M\nM"))
            .frame(maxWidth: .infinity)
            .hidden()
            .overlay(alignment: .top) {
                ViewThatFits(in: .vertical) {
                    ForEach(candidates, id: \.self) { candidate in
                        styled(Text(candidate))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    styled(Text(trimmedBio))
                        .lineLimit(2)
                }
            }
    }

    private var trimmedBio: String {
        bio.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The full bio, then shorter and shorter runs of whole sentences.
    private var candidates: [String] {
        let text = trimmedBio.replacingOccurrences(of: "\n", with: " ")
        var ends: [String.Index] = []
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if ".!?".contains(text[index]), next == text.endIndex || text[next] == " " {
                ends.append(next)
            }
            index = next
        }
        var result = [text]
        for end in ends.reversed() {
            let sentence = String(text[..<end]).trimmingCharacters(in: .whitespaces)
            if !sentence.isEmpty, !result.contains(sentence) { result.append(sentence) }
        }
        return result
    }

    private func styled(_ text: Text) -> some View {
        text
            .font(.gilroy(.medium, size: 14))
            .foregroundStyle(.white.opacity(0.65))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }
}

// MARK: - Flip Haptics

/// Lightweight, pre-warmed haptic bundle for the card flip. Soft ticks as faces
/// pass flat, crisp ticks as the card turns edge-on, and a solid snap on settle.
final class FlipHaptics {
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let medium = UIImpactFeedbackGenerator(style: .medium)

    func prepare() {
        soft.prepare()
        rigid.prepare()
        medium.prepare()
    }

    func tick(intensity: CGFloat) {
        soft.impactOccurred(intensity: max(0.3, min(intensity, 1.0)))
        soft.prepare()
    }

    func edge(intensity: CGFloat) {
        rigid.impactOccurred(intensity: max(0.3, min(intensity, 1.0)))
        rigid.prepare()
    }

    func snap() {
        medium.impactOccurred()
        medium.prepare()
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ProfileCardView(
            profile: ProfileCard(
                firstName: "Gaurang", lastName: "Pant",
                companyName: "Mattr",
                jobRole: "Founder",
                bio: "Building products people actually love to use.",
                phone: "+91 98765 43210",
                email: "gaurang@mattr.app",
                links: ["instagram": "@gaurang", "linkedin": "linkedin.com/in/gaurang", "x": "@gaurangpant", "github": "github.com/gaurang"],
                theme: .glacier
            )
        )
        .frame(width: 300, height: 460)
    }
}

// MARK: - Hero Card Sizing

/// Locked dimensions for the full-size profile card (Profile tab, onboarding).
/// Change these here only, so every screen stays identical.
enum ProfileCardLayout {
    static let aspectRatio: CGFloat = 300.0 / 460.0
    /// Card inset from the screen edge, in points.
    static let screenInset: CGFloat = 44
}

extension View {
    /// Sizes a `ProfileCardView` like the Profile tab's hero card.
    /// `containerPadding` is the horizontal padding the parent already applies.
    func heroCardFrame(containerPadding: CGFloat = 0) -> some View {
        self
            .aspectRatio(ProfileCardLayout.aspectRatio, contentMode: .fit)
            .padding(.horizontal, ProfileCardLayout.screenInset - containerPadding)
    }
}

// MARK: - Flip Gesture Modifier

/// Attaches the horizontal-only flip pan when flipping is allowed. Taps on
/// the card's buttons are unaffected either way.
private struct FlipGestureModifier: ViewModifier {
    let isEnabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.gesture(HorizontalPanGesture(onChanged: onChanged, onEnded: onEnded))
        } else {
            content
        }
    }
}
