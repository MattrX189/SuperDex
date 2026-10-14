//
//  BlockedUsersView.swift
//  SuperDex
//
//  Lists the people the current user has blocked and lets them unblock.
//

import SwiftUI

struct BlockedUsersView: View {
    @Environment(BlockStore.self) private var blockStore

    private let accent = Color(red: 0.45, green: 0.40, blue: 0.95)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if blockStore.blocked.isEmpty {
                    emptyState
                        .padding(.top, 100)
                } else {
                    ForEach(blockStore.blocked) { user in
                        row(for: user)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(AppBackground())
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.3))
            Text("No blocked users")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))
            Text("People you block won't appear in your Discover feed. You can unblock them here anytime.")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private func row(for user: BlockedUser) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 40, height: 40)

            Text(user.name.isEmpty ? "Blocked user" : user.name)
                .font(.gilroy(.semiBold, size: 15))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    blockStore.unblock(user.id)
                }
            } label: {
                Text("Unblock")
                    .font(.gilroy(.semiBold, size: 13))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(accent.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
