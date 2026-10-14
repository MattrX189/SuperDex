//
//  EmptyStateGuide.swift
//  SuperDex
//
//  First-run guide shown on empty tabs (Deck, Contacts): a hero icon,
//  a short pitch, numbered "how it works" steps, and a primary action.
//

import SwiftUI

struct EmptyStateGuide: View {
    struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    /// Which half to render, so a screen can put its own content
    /// between the pitch and the how-to (Deck puts events there).
    enum Part { case all, intro, howTo }

    let icon: String
    let accent: Color
    let title: String
    let subtitle: String
    let steps: [Step]
    var primaryTitle: String? = nil
    var primaryIcon: String = "plus"
    var primaryAction: (() -> Void)? = nil
    var footnote: String? = nil
    var part: Part = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if part != .howTo {
                intro
            }
            if part != .intro {
                howTo
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var intro: some View {
        hero
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)

        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.gilroy(.bold, size: 30))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.gilroy(.regular, size: 16))
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var howTo: some View {
        stepsCard

        if let primaryTitle, let primaryAction {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                primaryAction()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: primaryIcon)
                        .font(.system(size: 15, weight: .bold))
                    Text(primaryTitle)
                        .font(.gilroy(.semiBold, size: 16))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white)
                )
            }
            .buttonStyle(GroupCardPressStyle())
        }

        if let footnote {
            Text(footnote)
                .font(.gilroy(.medium, size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Three translucent glass cards fanned out like a hand of cards,
    /// with the icon on the front one.
    private var hero: some View {
        ZStack {
            heroCard(opacity: 0.06)
                .rotationEffect(.degrees(-9), anchor: .bottom)
                .offset(x: -26, y: 4)

            heroCard(opacity: 0.08)
                .rotationEffect(.degrees(9), anchor: .bottom)
                .offset(x: 26, y: 4)

            heroCard(opacity: 0.14)
                .rotationEffect(.degrees(4), anchor: .bottom)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .rotationEffect(.degrees(4))
                }
        }
        .frame(width: 180, height: 130)
        .background(
            RadialGradient(
                colors: [accent.opacity(0.18), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 110
            )
        )
    }

    private func heroCard(opacity: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [.white.opacity(opacity + 0.06), .white.opacity(opacity)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .frame(width: 92, height: 122)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.22))
                        Image(systemName: step.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(index + 1). \(step.title)")
                            .font(.gilroy(.semiBold, size: 15))
                            .foregroundStyle(.white)
                        Text(step.detail)
                            .font(.gilroy(.regular, size: 13))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gradientCard(accent: accent, cornerRadius: 24)
    }
}

#Preview {
    EmptyStateGuide(
        icon: "rectangle.stack.fill",
        accent: .indigo,
        title: "Build your first deck",
        subtitle: "A deck is a collection of people you met in the same place.",
        steps: [
            .init(icon: "plus", title: "Create a deck", detail: "Tap + and give it a name."),
            .init(icon: "person.2.fill", title: "Add people", detail: "Pick from your contacts."),
        ],
        primaryTitle: "Create a Deck",
        primaryAction: {}
    )
    .padding(20)
    .background(AppBackground())
    .preferredColorScheme(.dark)
}
