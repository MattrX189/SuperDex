//
//  HomeNudgeCards.swift
//  SuperDex
//
//  Onboarding nudges shown on Home: a "meet 5 people" streak and a
//  profile-completion checklist. Both hide themselves once done.
//

import SwiftUI

private let nudgeIndigo = Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0)
/// Streak fill: the same solid indigo as "Record an interaction".
private let streakColors = [nudgeIndigo, nudgeIndigo]

// MARK: - Profile completion

/// The basic details every profile should have to be useful when shared.
enum ProfileChecklistItem: String, CaseIterable, Identifiable {
    case jobTitle, company, bio, category, phone, whatsapp, instagram, linkedin, x

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jobTitle: return "Job title"
        case .company: return "Company"
        case .bio: return "Bio"
        case .category: return "Domain"
        case .phone: return "Phone"
        case .whatsapp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .linkedin: return "LinkedIn"
        case .x: return "X"
        }
    }

    /// SF Symbol, or nil when a brand icon asset is used instead.
    var symbol: String? {
        switch self {
        case .jobTitle: return "briefcase.fill"
        case .company: return "building.2.fill"
        case .bio: return "text.quote"
        case .category: return "square.grid.2x2.fill"
        case .phone: return "phone.fill"
        case .whatsapp, .instagram, .linkedin, .x: return nil
        }
    }

    var brandIcon: String? {
        switch self {
        case .whatsapp: return "whatsapp"
        case .instagram: return "instagram"
        case .linkedin: return "linkedin"
        case .x: return "x"
        default: return nil
        }
    }

    func isComplete(in profile: UserProfileData) -> Bool {
        func filled(_ value: String?) -> Bool {
            !(value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        switch self {
        case .jobTitle: return filled(profile.jobRole)
        case .company: return filled(profile.companyName)
        case .bio: return filled(profile.bio)
        case .category: return !profile.categories.isEmpty
        case .phone: return filled(profile.phone)
        case .whatsapp: return filled(profile.links[ProfileLink.whatsapp.rawValue])
        case .instagram: return filled(profile.links[ProfileLink.instagram.rawValue])
        case .linkedin: return filled(profile.links[ProfileLink.linkedin.rawValue])
        case .x: return filled(profile.links[ProfileLink.x.rawValue])
        }
    }
}

struct ProfileCompletionCard: View {
    let profile: UserProfileData
    let onEdit: () -> Void

    @State private var isExpanded = false

    private var items: [ProfileChecklistItem] { ProfileChecklistItem.allCases }
    private var doneCount: Int { items.filter { $0.isComplete(in: profile) }.count }
    private var progress: Double { Double(doneCount) / Double(items.count) }
    private var missing: [ProfileChecklistItem] { items.filter { !$0.isComplete(in: profile) } }

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 14) {
                    progressRing

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Complete your profile")
                            .font(.gilroy(.semiBold, size: 16))
                            .foregroundStyle(.white)
                        Text("\(missing.count) detail\(missing.count == 1 ? "" : "s") missing · people only see what you add")
                            .font(.gilroy(.regular, size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    whyItMatters

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(items) { item in
                            checklistRow(item)
                        }
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onEdit()
                    } label: {
                        Text("Fill in missing details")
                            .font(.gilroy(.semiBold, size: 15))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(.white))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(shape.fill(Color.white.opacity(0.04)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(shape)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: [nudgeIndigo, .purple, nudgeIndigo], center: .center),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%")
                .font(.gilroy(.bold, size: 12))
                .foregroundStyle(.white)
        }
        .frame(width: 46, height: 46)
        .animation(.smooth, value: progress)
    }

    private var whyItMatters: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.yellow)
                .padding(.top, 1)
            Text("When someone scans your card, these details are all they get. Missing a phone or LinkedIn means they can't follow up — and a clear role and bio help the right people find you on Discover.")
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.yellow.opacity(0.08))
        )
    }

    private func checklistRow(_ item: ProfileChecklistItem) -> some View {
        let done = item.isComplete(in: profile)
        return Button {
            if !done { onEdit() }
        } label: {
            HStack(spacing: 8) {
                Group {
                    if let brand = item.brandIcon {
                        BrandIcon(name: brand)
                    } else if let symbol = item.symbol {
                        Image(systemName: symbol)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(width: 14, height: 14)
                .foregroundStyle(.white.opacity(done ? 0.4 : 0.85))

                Text(item.title)
                    .font(.gilroy(.medium, size: 13))
                    .foregroundStyle(.white.opacity(done ? 0.4 : 0.9))
                    .strikethrough(done, color: .white.opacity(0.4))
                    .lineLimit(1)

                Spacer(minLength: 2)

                Image(systemName: done ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(done ? Color.green : nudgeIndigo)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(done ? 0.02 : 0.06))
            )
        }
        .buttonStyle(.plain)
        .disabled(done)
    }
}

// MARK: - Connection goal

/// "Meet 5 new people" streak shown until the first five connections are made.
struct ConnectionGoalCard: View {
    let count: Int
    var goal: Int = 5
    let onScan: () -> Void

    private var clamped: Int { min(count, goal) }
    private var remaining: Int { max(goal - count, 0) }
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    private var headline: String {
        switch clamped {
        case 0: return "Meet 5 new people"
        case goal - 1: return "One more to go!"
        default: return "\(remaining) more to go"
        }
    }

    private var subtitle: String {
        clamped == 0
            ? "Scan cards at your next event to start your streak."
            : "You've met \(clamped) of \(goal) — keep the streak going."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: clamped > 0 ? streakColors : [Color.white.opacity(0.10), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(clamped > 0 ? .white : .white.opacity(0.5))
                        .symbolEffect(.bounce, value: clamped)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(.gilroy(.semiBold, size: 16))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Text("\(clamped)/\(goal)")
                    .font(.gilroy(.bold, size: 15))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 6) {
                ForEach(0..<goal, id: \.self) { index in
                    streakSegment(filled: index < clamped)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: clamped)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onScan()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                    Text(clamped == 0 ? "Scan your first card" : "Scan a card")
                        .font(.gilroy(.semiBold, size: 15))
                }
                .foregroundStyle(nudgeIndigo)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(shape.fill(Color.white.opacity(0.04)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func streakSegment(filled: Bool) -> some View {
        Capsule()
            .fill(
                filled
                    ? AnyShapeStyle(LinearGradient(colors: streakColors, startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle(Color.white.opacity(0.10))
            )
            .frame(height: 8)
            .shadow(color: filled ? nudgeIndigo.opacity(0.5) : .clear, radius: 6)
    }
}
