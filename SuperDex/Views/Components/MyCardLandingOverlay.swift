//
//  MyCardLandingOverlay.swift
//  SuperDex
//
//  The last beat of onboarding, played on Home: the user's new card
//  flies back in, spins once, then genies into the My Card quick-action
//  tile so they see exactly where it lives. The tile is cut out of the
//  overlay, so it stays lit on top and the card pours in *under* it.
//  Shown by HomeView when UserProfileViewModel.celebrateMyCard is set.
//

import SwiftUI
import UIKit

struct MyCardLandingOverlay: View {
    let profile: ProfileCard
    /// The My Card tile, in global (screen) coordinates.
    let target: CGRect
    let onFinished: () -> Void

    @Environment(\.displayScale) private var displayScale

    @State private var showCard = false
    @State private var dimmed = false
    @State private var snapshot: UIImage?
    @State private var genieProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let rect = cardRect(in: geometry.size)
            ZStack {
                Color.black
                    .opacity(dimmed ? 0.55 : 0)

                if let snapshot {
                    GenieImage(
                        image: snapshot,
                        rect: rect,
                        target: CGPoint(x: target.midX, y: target.midY),
                        progress: genieProgress
                    )
                } else {
                    ProfileCardView(
                        profile: profile,
                        showsShadow: false,
                        spinOnAppear: true,
                        spinDelay: 0.45,
                        showsEmptyLinks: true
                    )
                    .frame(width: rect.width, height: rect.height)
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                    .position(x: rect.midX, y: rect.midY)
                    .scaleEffect(showCard ? 1 : 0.4)
                    .offset(y: showCard ? 0 : geometry.size.height * 0.7)
                    .opacity(showCard ? 1 : 0)
                }
            }
            // Punch the tile out of everything above, so it sits on top.
            .mask {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geometry.size))
                    path.addRoundedRect(
                        in: target,
                        cornerSize: CGSize(width: 22, height: 22),
                        style: .continuous
                    )
                }
                .fill(style: FillStyle(eoFill: true))
            }
            .task { await run(rect: rect) }
        }
        .ignoresSafeArea()
    }

    /// Centered card, kept below the tile — the genie pours upward.
    private func cardRect(in size: CGSize) -> CGRect {
        let width = (size.width - ProfileCardLayout.screenInset * 2) * 0.78
        let height = width / ProfileCardLayout.aspectRatio
        let centerY = max(size.height * 0.56, target.maxY + 48 + height / 2)
        return CGRect(x: (size.width - width) / 2, y: centerY - height / 2, width: width, height: height)
    }

    private func run(rect: CGRect) async {
        // Fly in from below.
        withAnimation(.easeOut(duration: 0.3)) { dimmed = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { showCard = true }

        // ProfileCardView spins itself (spinDelay 0.45 + ~1.3s); let it land.
        try? await Task.sleep(for: .milliseconds(2300))

        // Swap the live card for a still (same frame, so it's seamless) —
        // the genie slices an image, not the glass layers.
        snapshot = renderSnapshot(size: rect.size)
        guard snapshot != nil else { return finish() }

        try? await Task.sleep(for: .milliseconds(150))
        await runGenie(duration: 0.9)
        finish()
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.3)) { dimmed = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            onFinished()
        }
    }

    /// GenieImage draws from a plain value, so step it per frame.
    private func runGenie(duration: Double) async {
        let clock = ContinuousClock()
        let start = clock.now
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        while true {
            let elapsed = start.duration(to: clock.now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let t = min(seconds / duration, 1)
            genieProgress = CGFloat(t * t * (3 - 2 * t))
            if t >= 1 { break }
            try? await Task.sleep(for: .milliseconds(8))
        }
    }

    private func renderSnapshot(size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(
            content: ProfileCardView(profile: profile, showsShadow: false, showsEmptyLinks: true)
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = displayScale
        return renderer.uiImage
    }
}
