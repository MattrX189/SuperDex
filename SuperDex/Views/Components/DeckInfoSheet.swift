//
//  DeckInfoSheet.swift
//  SuperDex
//
//  The "What is a deck?" ⓘ sheet, shared by the Decks tab and Home.
//

import SwiftUI

extension EmptyStateGuide {
    /// The deck guide. `.howTo` is the Decks tab's first-run state;
    /// `.intro` ("what's a deck") is the ⓘ sheet.
    static func deck(_ part: Part, onCreate: @escaping () -> Void = {}) -> EmptyStateGuide {
        EmptyStateGuide(
            icon: "person.2.fill",
            accent: .indigo,
            title: "Decks are stacks of people",
            subtitle: "Organize the people you meet into Decks based on their job roles, companies, skills, or events.\n\nWith Decks, everyone is in one place. Easily find connections, explore their latest profiles, and stay up to date with their details, so you never lose track of someone important.",
            steps: [
                .init(
                    icon: "plus",
                    title: "Create a deck",
                    detail: "Tap the + button and give it a name, like \u{201C}Design Meetup\u{201D}."
                ),
                .init(
                    icon: "calendar.badge.clock",
                    title: "Add the details",
                    detail: "Optionally set a date, location, link, and a cover photo."
                ),
                .init(
                    icon: "person.2.fill",
                    title: "Add people",
                    detail: "Pick from your contacts, or scan someone's SuperDex QR to add them straight in."
                ),
                .init(
                    icon: "magnifyingglass",
                    title: "Find them later",
                    detail: "Search your decks by name, member, or place whenever you need to reconnect."
                )
            ],
            primaryTitle: "Create a Deck",
            primaryAction: onCreate,
            part: part
        )
    }
}

struct DeckInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                EmptyStateGuide.deck(.intro)

                // Same "Got it" as the Contacts ⓘ sheet.
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.gilroy(.semiBold, size: 16))
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
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }
}

/// The ⓘ button that opens `DeckInfoSheet`.
struct DeckInfoButton: View {
    var size: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("What is a deck?")
    }
}
