//
//  GigCardView.swift
//  SuperDex
//
//  Feed card for one gig post. One quiet indigo glow and a single
//  green accent (the coin + budget) — everything else stays calm
//  glass, matching the app's card language without the noise.
//

import SwiftUI

struct GigCardView: View {
    let post: GigPost
    let isOwn: Bool

    private let cornerRadius: CGFloat = 26
    private var accent: Color { .indigo }

    private let coinGreen = Color(red: 0.25, green: 0.85, blue: 0.45)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                iconBadge
                    .padding(.top, 2)

                cardContent
            }

            // Meta chips get the full card width (below the icon) so
            // budget/duration/location don't clip at the card edge.
            if post.budgetText != nil || post.durationText != nil || post.location != nil {
                metaChipsRow
                    .padding(.top, 12)
            }

            bottomRow
                .padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Signature indigo gradient card, matching GroupCardView.
        .gradientCard(accent: accent, cornerRadius: cornerRadius)
    }

    /// Gradient icon badge, matching GroupCardView's thumbnail: an
    /// indigo gradient rounded square with a top-left highlight,
    /// border, white briefcase, and a soft accent shadow.
    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
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

            Image(systemName: "banknote.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
        .frame(width: 56, height: 56)
        .shadow(color: accent.opacity(0.55), radius: 10, y: 6)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text(post.title)
                    .font(.gilroy(.bold, size: 17))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if isOwn {
                    badge("Your post")
                } else if post.hasApplied {
                    badge("Applied")
                }
            }

            Text(post.descriptionText)
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.60))
                .lineSpacing(2)
                .lineLimit(2)
                .padding(.top, 7)
        }
    }

    /// Budget in green, the rest quiet; scrolls when longer than the card.
    private var metaChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let budget = post.budgetText {
                    metaChip(icon: "tag.fill", text: budget, tint: coinGreen)
                }
                if let duration = post.durationText {
                    metaChip(icon: "clock.fill", text: duration, tint: accent)
                }
                if let location = post.location {
                    metaChip(icon: "mappin.and.ellipse", text: location, tint: accent)
                }
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 8) {
            // Applicant count is private to the poster.
            if isOwn {
                Text(applicantsText)
            }

            Spacer(minLength: 12)

            Text(post.postedAgo)
        }
        .font(.gilroy(.medium, size: 12))
        .foregroundStyle(.white.opacity(0.45))
        .lineLimit(1)
    }

    private var applicantsText: String {
        switch post.applicantCount {
        case 0:  return "No applicants yet"
        case 1:  return "1 applicant"
        default: return "\(post.applicantCount) applicants"
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.gilroy(.semiBold, size: 10))
            .tracking(0.8)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .glassEffect(.regular.interactive(), in: Capsule())
    }

    private func metaChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.gilroy(.semiBold, size: 11))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular.interactive(), in: Capsule())
    }
}
