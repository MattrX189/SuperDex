//
//  GroupCardView.swift
//  HomeScreen
//

import SwiftUI

struct GroupCardView: View {
    let group: CardGroup
    var onTap: () -> Void = {}

    private let cornerRadius: CGFloat = 26

    private var previewProfiles: [ProfileCard] {
        Array(group.profileCards.prefix(4))
    }

    private var memberCount: Int { group.members.count }

    var body: some View {
        HStack(spacing: 16) {
            leadingBadge

            VStack(alignment: .leading, spacing: 8) {
                Text(group.name)
                    .font(.gilroy(.bold, size: 16))
                    .tracking(2.0)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    avatarStack

                    Text("\(memberCount) members")
                        .font(.gilroy(.medium, size: 12))
                        .foregroundStyle(.white.opacity(0.6))
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
        .shadow(color: group.color.opacity(0.30), radius: 18, y: 12)
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Leading badge

    @ViewBuilder
    private var leadingBadge: some View {
        if let data = group.wallpaperData, let uiImage = UIImage(data: data) {
            wallpaperBadge(uiImage: uiImage)
        } else {
            iconBadge
        }
    }

    private func wallpaperBadge(uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.40), radius: 8, y: 4)
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            group.color,
                            group.color.opacity(0.55)
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

            Image(systemName: group.icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
        .frame(width: 56, height: 56)
        .shadow(color: group.color.opacity(0.55), radius: 10, y: 6)
    }

    // MARK: - Avatars

    private var avatarStack: some View {
        HStack(spacing: -8) {
            ForEach(Array(previewProfiles.prefix(3).enumerated()), id: \.element.id) { idx, profile in
                Image(profile.avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color(red: 0.06, green: 0.08, blue: 0.13), lineWidth: 1)
                    )
                    .zIndex(Double(3 - idx))
            }

            if memberCount > 3 {
                Text("+\(memberCount - 3)")
                    .font(.gilroy(.semiBold, size: 9))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(Color.white.opacity(0.18))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color(red: 0.06, green: 0.08, blue: 0.13), lineWidth: 1)
                    )
            }
        }
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
        gradientBackground
    }

    private var gradientBackground: some View {
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
                colors: [group.color.opacity(0.40), .clear],
                center: UnitPoint(x: 0.0, y: 0.0),
                startRadius: 0,
                endRadius: 240
            )

            RadialGradient(
                colors: [group.color.opacity(0.20), .clear],
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
                        group.color.opacity(0.55),
                        .white.opacity(0.10),
                        .clear,
                        group.color.opacity(0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

struct GroupCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            GroupCardView(group: CardGroup(name: "OpenAI"))
            GroupCardView(group: CardGroup(name: "Anthropic"))
            GroupCardView(group: CardGroup(name: "Design Team"))
        }
        .padding(20)
    }
    .preferredColorScheme(.dark)
}
