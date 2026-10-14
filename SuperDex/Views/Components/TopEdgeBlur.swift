//
//  TopEdgeBlur.swift
//  SuperDex
//
//  Soft blur behind the status bar that fades in once content scrolls
//  under it (like Apple's apps). The tab root owns the blur; its main
//  ScrollView reports scroll state via `.reportsTopScroll()`.
//

import SwiftUI

extension EnvironmentValues {
    /// Set by `topEdgeBlur()`; called with `true` once content scrolls under the status bar.
    @Entry var topScrollReporter: ((Bool) -> Void)? = nil
}

private struct TopEdgeBlur: ViewModifier {
    /// How far the fade extends below the status bar.
    var fadeHeight: CGFloat

    @State private var isScrolled = false

    func body(content: Content) -> some View {
        content
            .environment(\.topScrollReporter) { scrolled in
                guard scrolled != isScrolled else { return }
                withAnimation(.easeInOut(duration: 0.2)) { isScrolled = scrolled }
            }
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    let inset = geo.safeAreaInsets.top
                    let height = inset + fadeHeight
                    // Solid under the status bar, then fades out.
                    let solidStop = height > 0 ? inset / height : 0

                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Color.black.opacity(0.25)
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: solidStop * 0.7),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: geo.size.width, height: height)
                    .offset(y: -inset)
                    .opacity(isScrolled ? 1 : 0)
                }
                .allowsHitTesting(false)
            }
    }
}

private struct ReportsTopScroll: ViewModifier {
    @Environment(\.topScrollReporter) private var report
    @State private var isScrolled = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 2
            } action: { _, scrolled in
                isScrolled = scrolled
                report?(scrolled)
            }
            // Re-sync when navigating back to / away from this screen.
            .onAppear { report?(isScrolled) }
            .onDisappear { report?(false) }
    }
}

extension View {
    /// Adds a status-bar blur that appears once a reporting ScrollView scrolls.
    func topEdgeBlur(fadeHeight: CGFloat = 24) -> some View {
        modifier(TopEdgeBlur(fadeHeight: fadeHeight))
    }

    /// Apply to a screen's main vertical ScrollView to drive `topEdgeBlur()`.
    func reportsTopScroll() -> some View {
        modifier(ReportsTopScroll())
    }
}
