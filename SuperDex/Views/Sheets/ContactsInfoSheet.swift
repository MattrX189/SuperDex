//
//  ContactsInfoSheet.swift
//  SuperDex
//
//  The ⓘ next to the Contacts title: what saving someone on SuperDex
//  gets you. Leads with live profiles, then puts the weight on the
//  things a phonebook can't do — interactions, searching by where you met,
//  decks — and ends with how the phone's address book fits in.
//

import SwiftUI

struct ContactsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                intro
                highlights
                phonebookNote

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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("People, not phone numbers")
                .font(.gilroy(.bold, size: 30))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Add the people you meet by scanning their SuperDex QR or connecting on Discover. Each one is a living profile: their socials, portfolio, role and company stay live and update whenever they change them.")
                .font(.gilroy(.regular, size: 16))
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Highlights (the emphasis)

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("More than a contact list")
                .font(.gilroy(.bold, size: 20))
                .foregroundStyle(.white)

            featureRow(
                icon: "sparkles.rectangle.stack.fill",
                title: "Remember where you met",
                detail: "Log an interaction with anyone: where you met and what you talked about. It's right there on their card the next time you reach out."
            )
            featureRow(
                icon: "magnifyingglass",
                title: "Search the way you remember",
                detail: "Find people by their job, their company, or where you met them, not just by name."
            )
            featureRow(
                icon: "rectangle.stack.fill",
                title: "Group them in decks",
                detail: "Sort people into decks by event, team or trip, so everyone from that conference is in one place. To add several people at once, tap \u{2022}\u{2022}\u{2022} \u{2192} Add to Deck at the top of Contacts."
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gradientCard(accent: accent, cornerRadius: 24)
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.22))
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.gilroy(.regular, size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Phonebook

    private var phonebookNote: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("Your phonebook stays yours")
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)
                Text("SuperDex contacts aren't added to your phone's contacts automatically. Want someone there too? Open their card and tap the \(Image(systemName: "person.crop.circle.badge.plus")) button to save them.")
                    .font(.gilroy(.regular, size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            ContactsInfoSheet()
        }
        .preferredColorScheme(.dark)
}
