//
//  ProfileCardsViewModel.swift
//  HomeScreen
//

import SwiftUI

@Observable
final class ProfileCardsViewModel {
    var profiles: [ProfileCard]
    var dragOffset: CGSize = .zero
    var currentIndex: Int = 0

    init(profiles: [ProfileCard], startingIndex: Int = 0) {
        self.profiles = profiles
        self.currentIndex = max(0, min(startingIndex, max(profiles.count - 1, 0)))
    }

    func swipeLeft(cardWidth: CGFloat) {
        if currentIndex < profiles.count - 1 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentIndex += 1
            }
        }
    }

    func swipeRight(cardWidth: CGFloat) {
        if currentIndex > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentIndex -= 1
            }
        }
    }

    func handleDragEnd(translation: CGFloat, cardWidth: CGFloat) {
        let threshold = cardWidth * 0.25
        if translation < -threshold && currentIndex < profiles.count - 1 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentIndex += 1
            }
        } else if translation > threshold && currentIndex > 0 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentIndex -= 1
            }
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            dragOffset = .zero
        }
    }

    func relativePosition(of index: Int) -> Int {
        let rel = index - currentIndex
        if rel < -1 { return -2 }
        if rel > 1 { return 2 }
        return rel
    }

    func zIndex(for relative: Int) -> Double {
        switch relative {
        case 0: return 3
        case -1, 1: return 2
        default: return 1
        }
    }
}
