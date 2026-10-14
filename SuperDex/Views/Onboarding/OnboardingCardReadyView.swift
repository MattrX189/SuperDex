//
//  OnboardingCardReadyView.swift
//  SuperDex
//

import SwiftUI
import UIKit

/// Final onboarding screen: the finished card, launched like a slingshot.
///
/// 1. Entrance: title, card rises and spins (unchanged).
/// 2. Aim: pull the card down. Energy gathers into the card (ChargeEnergyView:
///    streaks, rings, shards, edge lightning) and the problems
///    SuperDex solves appear above it, one by one, as they're uncovered.
/// 3. Fire: let go past the threshold — the stored energy releases
///    (flash, shockwaves) and the card shoots up through the problems,
///    bursting them.
/// 4. "Welcome to" + the SuperDex wordmark, then onboarding completes.
///    Home picks up from there (MyCardLandingOverlay): the card flies
///    back in, spins, and genies into the My Card tile.
struct OnboardingCardReadyView: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    let accent: Color
    let onContinue: () -> Void

    // Entrance
    @State private var showTitle = false
    @State private var showCard = false
    @State private var showHint = false
    @State private var floating = false

    // Slingshot
    private enum Phase { case aiming, firing, welcome }
    @State private var phase: Phase = .aiming
    @State private var pull: CGFloat = 0
    @State private var isVerticalDrag: Bool?
    @State private var revealedCount = 0
    /// Which "hold" message is showing at full draw (nil below it).
    @State private var holdStage: Int?
    @State private var launched = false
    @State private var burst = false

    // Welcome
    @State private var showWelcome = false

    /// The card's resting layout frame in the stage's coordinate space.
    @State private var cardFrame: CGRect = .zero
    @State private var stageSize: CGSize = .zero
    /// Particle state for the charge (a class: stepped every frame from
    /// the Canvas without triggering view updates).
    @State private var energy = EnergyField()
    @State private var chargeHaptics = ChargeHaptics()
    /// When and where the card was let go, for the release burst.
    @State private var releaseStart: Date?
    @State private var releaseCenter: CGPoint = .zero
    /// Fades the stage to Home's background as the energy clears out.
    @State private var exitFade = false

    private let maxPull: CGFloat = 260
    /// Full draw: the fraction of maxPull where the card counts as pulled to
    /// the bottom. Starts the hold countdown; firing also needs "Release it!".
    private let fireThreshold: CGFloat = 0.9

    private let problems: [(icon: String, text: String)] = [
        ("person.crop.rectangle.badge.xmark", "Profiles that go out of date"),
        ("mappin.slash", "\u{201C}Where did we meet again?\u{201D}"),
        ("bubble.left.and.exclamationmark.bubble.right", "\u{201C}What did we talk about?\u{201D}"),
        ("briefcase", "Need to hire someone fast"),
        ("rectangle.stack.badge.minus", "Lost business cards"),
        ("link", "Socials scattered everywhere"),
        ("questionmark.circle", "\u{201C}Wait, what's their name?\u{201D}"),
        ("building.2", "Who works where now?")
    ]

    private var glowColor: Color {
        viewModel.profile.theme.gradientColors.first ?? accent
    }

    private var progress: CGFloat { min(pull / maxPull, 1) }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [glowColor.opacity(0.35), .clear],
                center: UnitPoint(x: 0.5, y: 0.55),
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()
            .opacity(showCard ? 1 : 0)
            .animation(.easeOut(duration: 1.0), value: showCard)

            // Behind the card, so energy disappears under its edges.
            ChargeEnergyBackground(
                card: aimedCardRect,
                progress: progress,
                armed: progress >= fireThreshold,
                color: glowColor,
                field: energy,
                isActive: phase == .aiming && pull > 0
            )
            // Through the home-indicator area (bottom only, so the top
            // origin — and the card's coordinates — stay the same).
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                header
                    .padding(.top, 24)
                    // Gone almost as soon as the pull starts — the pull
                    // heading takes over that space.
                    .opacity(phase == .aiming ? 1 - min(pull / 18, 1) : 0)

                Spacer(minLength: 20)

                card

                Text("Swipe the card to flip it")
                    .font(.gilroy(.medium, size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 16)
                    .opacity(showHint && phase == .aiming ? 1 - progress * 3 : 0)

                Spacer(minLength: 20)

                pullHint
            }

            ChargeEdgeLightning(
                card: aimedCardRect,
                progress: progress,
                armed: progress >= fireThreshold,
                color: glowColor,
                isActive: phase == .aiming && pull > 0
            )
            .ignoresSafeArea(edges: .bottom)
            problemChips
            pullHeading
            if let releaseStart {
                EnergyReleaseBurst(center: releaseCenter, start: releaseStart, color: glowColor)
                    .ignoresSafeArea(edges: .bottom)
            }
            // Welcome screen disabled for now (see fire()).
            // welcomeLayer

            // Exit: the blue stage gives way to Home's own background, so
            // Home can settle in without a cut.
            AppBackground()
                .ignoresSafeArea()
                .opacity(exitFade ? 1 : 0)
                .allowsHitTesting(false)
        }
        .coordinateSpace(.named("stage"))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { stageSize = $0 }
        .task { await runEntrance() }
        .onDisappear { chargeHaptics.cancel() }
        // Once every problem is out and the shot is armed, step through the
        // hold messages while it's held.
        .task(id: isHoldingFullDraw) {
            guard isHoldingFullDraw else {
                withAnimation(.easeOut(duration: 0.2)) { holdStage = nil }
                return
            }
            for stage in holdMessages.indices {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { holdStage = stage }
                holdStageHaptic(stage)
                guard stage < holdMessages.count - 1 else { return }
                try? await Task.sleep(for: .milliseconds(850))
                if Task.isCancelled { return }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("Your card is ready")
                .font(.gilroy(.bold, size: 30))
                .foregroundStyle(.white)

            Text("Share it instantly with a tap or a scan.")
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.55))
        }
        .multilineTextAlignment(.center)
        .opacity(showTitle ? 1 : 0)
        .offset(y: showTitle ? 0 : 12)
    }

    // MARK: - Card

    private var card: some View {
        // Same sizing as the Profile tab's hero card.
        ProfileCardView(
            profile: viewModel.profile.asProfileCard,
            showsShadow: false,
            allowsFlip: true,
            spinOnAppear: true,
            spinDelay: 0.6,
            showsEmptyLinks: true
        )
            .aspectRatio(ProfileCardLayout.aspectRatio, contentMode: .fit)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("stage")) } action: { frame in
                if phase == .aiming, pull == 0 { cardFrame = frame }
            }
            .shadow(color: glowColor.opacity(0.35), radius: 30, y: 16)
            .padding(.horizontal, ProfileCardLayout.screenInset)
            // Entrance: rises up and settles
            .scaleEffect(showCard ? 1 : 0.92)
            .offset(y: showCard ? 0 : 60)
            .opacity(showCard ? 1 : 0)
            // Idle: slow, subtle float (paused while aiming)
            .offset(y: floating && pull == 0 ? -6 : 0)
            // Aim: shrink toward the bottom and drop with the pull. (No 3D
            // tilt — the energy layers trace the card's flat frame exactly.)
            .scaleEffect(1 - cardShrink * progress, anchor: .bottom)
            .offset(y: pull)
            // Fire: shrink and shoot up off the top (scale first, so it
            // doesn't also shrink the distance travelled)
            .scaleEffect(launched ? 0.5 : 1)
            .offset(y: launched ? -(cardFrame.maxY + 120) : 0)
            .simultaneousGesture(pullGesture)
            .accessibilityAction(named: "Launch card") { fire() }
    }

    /// The card's top edge right now, for the charge
    /// and for uncovering problems.
    private var currentCardTop: CGFloat {
        cardFrame.minY + pull + cardFrame.height * cardShrink * progress
    }

    /// How much the card shrinks (toward its bottom edge) at full draw.
    private let cardShrink: CGFloat = 0.2

    // MARK: - Pull gesture

    private var pullGesture: some Gesture {
        // Global space: the card moves with the pull, so measuring in its
        // own space would feed the movement back into the gesture (jitter).
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in
                guard phase == .aiming, showHint else { return }
                if isVerticalDrag == nil {
                    // Decide once per drag: down = aim, sideways = flip.
                    isVerticalDrag = value.translation.height > abs(value.translation.width)
                }
                guard isVerticalDrag == true else { return }

                // Follows the finger 1:1 up to full draw, then resists.
                let raw = max(0, value.translation.height)
                pull = raw <= maxPull ? raw : maxPull + (raw - maxPull) * 0.15
                chargeHaptics.update(progress: progress)
                updateRevealed()
            }
            .onEnded { _ in
                defer { isVerticalDrag = nil }
                guard isVerticalDrag == true, phase == .aiming else { return }
                if canRelease {
                    fire()
                } else {
                    chargeHaptics.cancel()
                    // Same snap-back feel as the card's flip.
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                        pull = 0
                        revealedCount = 0
                    }
                }
            }
    }

    private func updateRevealed() {
        let count = problemPositions.prefix { $0.y + 24 < currentCardTop }.count
        guard count != revealedCount else { return }
        if count > revealedCount {
            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred(intensity: 0.5 + 0.5 * progress)
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            revealedCount = count
        }
    }

    // MARK: - Problems

    /// Chip centers, stacked top-down in the space the pulled card uncovers.
    private var problemPositions: [CGPoint] {
        guard cardFrame != .zero else { return [] }
        let top: CGFloat = 112  // below the pull heading
        // The last problem is uncovered at ~80% of the draw, so every one
        // is out before the hold countdown starts.
        let revealAllTop = cardFrame.minY + 0.8 * (maxPull + cardFrame.height * cardShrink)
        let bottom = revealAllTop - 30
        let step = (bottom - top) / CGFloat(max(problems.count - 1, 1))
        return problems.indices.map { index in
            CGPoint(
                x: stageSize.width * (index.isMultiple(of: 2) ? 0.37 : 0.63),
                y: top + step * CGFloat(index)
            )
        }
    }

    private var problemChips: some View {
        TimelineView(.animation(paused: phase != .aiming || revealedCount == 0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(Array(zip(problems.indices, problemPositions)), id: \.0) { index, position in
                    if index < revealedCount || burst {
                        problemChip(problems[index], index: index)
                            // Tension wobble — stronger the further you pull.
                            .offset(
                                x: burst ? 0 : sin(time * 9 + Double(index)) * 2.5 * progress,
                                y: burst ? 0 : cos(time * 7 + Double(index)) * 1.5 * progress
                            )
                            .modifier(BurstEffect(
                                active: burst,
                                direction: burstDirection(from: position),
                                seed: index
                            ))
                            .position(position)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func problemChip(_ problem: (icon: String, text: String), index: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: problem.icon)
                .font(.system(size: 12, weight: .semibold))
            Text(problem.text)
                .font(.gilroy(.semiBold, size: 13))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color(red: 0.55, green: 0.14, blue: 0.2).opacity(0.55)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -3 : 3))
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }

    private func burstDirection(from point: CGPoint) -> CGVector {
        let dx = point.x - stageSize.width / 2
        let dy = point.y - stageSize.height * 0.35
        let length = max(sqrt(dx * dx + dy * dy), 1)
        return CGVector(dx: dx / length, dy: dy / length)
    }

    // MARK: - Charge

    /// The card's on-screen frame while aiming (pulled down and shrunk
    /// toward its bottom edge).
    private var aimedCardRect: CGRect {
        guard cardFrame != .zero else { return .zero }
        let scale = 1 - cardShrink * progress
        return CGRect(
            x: cardFrame.midX - cardFrame.width * scale / 2,
            y: currentCardTop,
            width: cardFrame.width * scale,
            height: cardFrame.height * scale
        )
    }

    // MARK: - Pull heading

    /// The shot only fires once it's fully drawn and held through the
    /// countdown to "Release it!" — letting go earlier springs it back.
    private var canRelease: Bool {
        isHoldingFullDraw && holdStage == holdMessages.count - 1
    }

    private var isHoldingFullDraw: Bool {
        phase == .aiming && progress >= fireThreshold && revealedCount == problems.count
    }

    /// "Supercharged" / "Release it!" always glow in SuperDex's own color,
    /// whatever theme the user picked for their card.
    private var brandGlow: Color {
        CardTheme.superDex.gradientColors.first ?? accent
    }

    /// Shown at full draw, one after another, while the card is held.
    private let holdMessages = [
        "Ready to kill all the problems?",
        "Hold it\u{2026}",
        "Supercharged \u{26A1}\u{FE0F}",
        "Release it!"
    ]

    /// Top of the screen while pulling: sets up the problems, then (at full
    /// draw) counts up to the release.
    private var pullHeading: some View {
        ZStack {
            if let stage = holdStage {
                Text(holdMessages[stage])
                    .font(.gilroy(.bold, size: stage == holdMessages.count - 1 ? 32 : 26))
                    .foregroundStyle(
                        stage >= 2
                            ? AnyShapeStyle(LinearGradient(colors: [.white, brandGlow], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.white)
                    )
                    .shadow(color: brandGlow.opacity(stage >= 2 ? 0.8 : 0), radius: 14)
                    .id(stage)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else {
                Text("For years, people have faced these problems while networking")
                    .font(.gilroy(.bold, size: 21))
                    .foregroundStyle(.white.opacity(0.92))
                    .transition(.opacity)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 28)
        .frame(width: stageSize.width, height: 80)
        .position(x: stageSize.width / 2, y: 52)
        .opacity(phase == .aiming ? min(pull / 30, 1) : 0)
        .allowsHitTesting(false)
    }

    private func holdStageHaptic(_ stage: Int) {
        switch stage {
        case 0: UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case 1: UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
        case 2: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        default: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    // MARK: - Pull hint (replaces "Let's Go")

    private var pullHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .symbolEffect(.bounce.down.byLayer, options: .repeat(.periodic(delay: 0.8)), isActive: showHint)
            Text("Pull the card all the way down")
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white)
        }
        .padding(.bottom, 28)
        // Gets out of the way as soon as the card comes down over it.
        .opacity(showHint && phase == .aiming ? 1 - min(progress * 6, 1) : 0)
        .offset(y: showHint ? 0 : 16)
    }

    // MARK: - Welcome

    private var welcomeLayer: some View {
        VStack(spacing: 18) {
            Text("Welcome to")
                .font(.gilroy(.semiBold, size: 22))
                .foregroundStyle(.white.opacity(0.75))
            Image("Splash")
                .resizable()
                .scaledToFit()
                .frame(width: min(stageSize.width * 0.72, 300))
        }
        .scaleEffect(showWelcome ? 1 : 0.5)
        .opacity(showWelcome ? 1 : 0)
        .position(x: stageSize.width / 2, y: stageSize.height * 0.45)
        .allowsHitTesting(false)
    }

    // MARK: - Sequences

    private func runEntrance() async {
        withAnimation(.easeOut(duration: 0.45)) { showTitle = true }

        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { showCard = true }

        // Card spins once on its own (spinDelay 0.6s, ~1.3s long) — reveal the
        // hint after it lands.
        try? await Task.sleep(for: .milliseconds(1800))
        withAnimation(.easeOut(duration: 0.4)) { showHint = true }

        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { floating = true }
    }

    private func fire() {
        guard phase == .aiming else { return }
        let rect = aimedCardRect
        releaseCenter = CGPoint(x: rect.midX, y: rect.minY + min(rect.height, stageSize.height - rect.minY) * 0.35)
        releaseStart = .now
        phase = .firing
        chargeHaptics.release()

        // Card shoots up; the charge releases with it.
        withAnimation(.easeIn(duration: 0.3)) {
            launched = true
            pull = 0
        }

        Task { @MainActor in
            // It reaches the problems almost immediately — burst them all.
            try? await Task.sleep(for: .milliseconds(160))
            revealedCount = problems.count
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Accelerating out, so they leave the screen rather than fade.
            withAnimation(.easeIn(duration: 0.75)) { burst = true }

            // As the problems and energy clear the screen, fade to Home's
            // background…
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeInOut(duration: 0.55)) { exitFade = true }
            try? await Task.sleep(for: .milliseconds(600))

            // "Welcome to" + SuperDex screen — disabled for now. To restore,
            // uncomment this and `welcomeLayer` in body.
            // phase = .welcome
            // withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { showWelcome = true }
            // try? await Task.sleep(for: .milliseconds(900))

            // Hand off to Home, which flies the card back in and genies it
            // into My Card.
            viewModel.celebrateMyCard = true
            // Home then settles in from the burst (View.homeEntrance).
            withAnimation(.easeOut(duration: 0.3)) { onContinue() }
        }
    }
}

// MARK: - Burst

/// Flings a problem chip outward off the screen, with a few sparks.
private struct BurstEffect: ViewModifier {
    let active: Bool
    let direction: CGVector
    let seed: Int

    func body(content: Content) -> some View {
        // Far enough to leave the screen from anywhere.
        let distance: CGFloat = 900 + CGFloat(seed % 3) * 150
        content
            .scaleEffect(active ? 1.4 : 1)
            .blur(radius: active ? 3 : 0)
            .opacity(active ? 0.4 : 1)
            .rotationEffect(.degrees(active ? Double(seed.isMultiple(of: 2) ? -25 : 25) : 0))
            .offset(x: active ? direction.dx * distance : 0, y: active ? direction.dy * distance : 0)
            .background {
                ZStack {
                    ForEach(0..<6, id: \.self) { spark in
                        let angle = Double(spark) / 6 * 2 * .pi + Double(seed)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 5, height: 5)
                            .offset(
                                x: active ? cos(angle) * 320 : 0,
                                y: active ? sin(angle) * 320 : 0
                            )
                            .opacity(active ? 0 : 0.9)
                            .scaleEffect(active ? 0.2 : 1)
                    }
                }
                .opacity(active ? 1 : 0)
            }
    }
}
