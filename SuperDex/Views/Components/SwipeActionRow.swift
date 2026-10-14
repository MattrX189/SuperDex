//
//  SwipeActionRow.swift
//  SuperDex
//
//  Swipe-left-to-reveal Edit/Delete actions for custom card rows.
//  SwiftUI's swipeActions only works inside List; the group lists
//  are custom cards in ScrollViews, so this wraps a row and slides
//  it aside to expose the actions.
//

import SwiftUI

struct SwipeActionRow<Content: View>: View {
    let accent: Color
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var dragBaseOffset: CGFloat?
    /// Set while a horizontal swipe is in progress.
    @State private var dragAxis: Axis?

    private let revealWidth: CGFloat = 128

    var body: some View {
        ZStack(alignment: .trailing) {
            actionButtons
                .opacity(min(1, -offset / revealWidth))

            content
                .offset(x: offset)
                // Disabling mid-drag cancels the NavigationLink's
                // in-flight press — otherwise releasing a swipe would
                // count as a tap and push the detail view. Also keeps
                // the link inert while the row sits open.
                .disabled(dragAxis == .horizontal || offset < -1)
                // While open, a tap anywhere on the card closes it
                // instead of navigating into the group. (The overlay
                // isn't affected by the .disabled above.)
                .overlay {
                    if offset < -10 {
                        Color.black.opacity(0.001)
                            .offset(x: offset)
                            .onTapGesture { close() }
                    }
                }
                // UIKit pan that only begins for horizontal swipes. A SwiftUI
                // DragGesture here (even as simultaneousGesture) swallows the
                // vertical pan on iOS 18+, so the ScrollView couldn't scroll
                // when a drag started on a card.
                .gesture(HorizontalPanGesture(onChanged: dragChanged, onEnded: dragEnded))
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            actionButton(icon: "pencil", color: accent) {
                close()
                onEdit()
            }
            actionButton(icon: "trash.fill", color: .red) {
                close()
                onDelete()
            }
        }
        .padding(.trailing, 4)
    }

    private func actionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(Circle().fill(color.opacity(0.35)))
                .overlay(Circle().strokeBorder(color.opacity(0.8), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func dragChanged(_ translation: CGFloat) {
        dragAxis = .horizontal

        let base = dragBaseOffset ?? offset
        if dragBaseOffset == nil { dragBaseOffset = offset }

        var proposed = min(0, base + translation)
        if proposed < -revealWidth {
            // Rubber-band past the fully revealed position.
            proposed = -revealWidth + (proposed + revealWidth) / 3
        }
        offset = proposed
    }

    private func dragEnded(_ translation: CGFloat, velocity: CGFloat) {
        dragAxis = nil
        dragBaseOffset = nil

        let shouldOpen = offset < -revealWidth / 2 || velocity < -600
        let shouldClose = velocity > 600
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            offset = (shouldOpen && !shouldClose) ? -revealWidth : 0
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            offset = 0
        }
    }
}

// MARK: - Horizontal Pan

/// Pan recognizer that refuses to begin unless the initial movement is
/// mostly horizontal, so vertical drags fall through to the ScrollView.
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .began, .changed:
            onChanged(translation)
        case .ended, .cancelled, .failed:
            onEnded(translation, recognizer.velocity(in: recognizer.view).x)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}
