//
//  PrivacyVisibilityView.swift
//  SuperDex
//
//  Premium-only screen that lets the user choose, per field, what to
//  expose on the Discover page and what to share via QR scan.
//

import SwiftUI

struct PrivacyVisibilityView: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ProfileVisibility()
    @State private var surface: PrivacySurface = .discover

    private let accent = Color.indigo

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                surfacePicker
                if surface == .discover {
                    discoverOptOutCard
                }
                if !(surface == .discover && draft.hiddenFromDiscover) {
                    ForEach(Array(ProfileField.allGroups.enumerated()), id: \.offset) { _, group in
                        fieldGroup(title: group.title, fields: group.fields)
                    }
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .preferredColorScheme(.dark)
        .navigationTitle("Privacy & Visibility")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    save()
                    dismiss()
                }
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white)
            }
        }
        .onAppear {
            draft = viewModel.profile.visibility
            viewModel.needsPrivacySetup = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(surface == .discover
                 ? "Choose what others can see when they find you on Discover."
                 : "Choose what gets shared when someone scans your QR code.")
                .font(.gilroy(.medium, size: 14))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var surfacePicker: some View {
        HStack(spacing: 8) {
            surfaceChip(label: "Discover", value: .discover, icon: "globe")
            surfaceChip(label: "QR Share", value: .qr, icon: "qrcode")
        }
    }

    private func surfaceChip(label: String, value: PrivacySurface, icon: String) -> some View {
        let isSelected = surface == value
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { surface = value }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.gilroy(.semiBold, size: 14))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.25) : .white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? accent.opacity(0.6) : .white.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var discoverOptOutCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.18))
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hide me from Discover")
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)
                Text("Your profile won't appear in the Discover feed")
                    .font(.gilroy(.medium, size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $draft.hiddenFromDiscover)
                .labelsHidden()
                .tint(.orange)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func fieldGroup(title: String, fields: [ProfileField]) -> some View {
        let visibleFields = fields.filter { surface.includes($0) }
        return VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.gilroy(.semiBold, size: 11))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(visibleFields.enumerated()), id: \.offset) { index, field in
                    if index > 0 { divider }
                    toggleRow(field)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
    }

    private func toggleRow(_ field: ProfileField) -> some View {
        let binding = Binding<Bool>(
            get: { draft.isVisible(field, on: surface) },
            set: { draft.setVisible(field, on: surface, $0) }
        )
        return HStack(spacing: 12) {
            iconView(for: field)
                .frame(width: 26, height: 26)

            Text(field.displayName)
                .font(.gilroy(.semiBold, size: 15))
                .foregroundStyle(.white)

            Spacer()

            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func iconView(for field: ProfileField) -> some View {
        switch field {
        case .link(let raw):
            if let link = ProfileLink(rawValue: raw) {
                if let brand = link.brandIconName {
                    BrandIcon(name: brand)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: link.fallbackSymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        default:
            Image(systemName: systemIcon(for: field))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func systemIcon(for field: ProfileField) -> String {
        switch field {
        case .name: return "person.fill"
        case .username: return "at"
        case .jobTitle: return "briefcase.fill"
        case .company: return "building.2.fill"
        case .bio: return "text.quote"
        case .phone: return "phone.fill"
        case .email: return "envelope.fill"
        case .category: return "tag.fill"
        case .portfolio: return "photo.on.rectangle.angled"
        case .link: return "link"
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 50)
    }

    private func save() {
        viewModel.profile.visibility = draft
        viewModel.saveProfileImmediately()
    }
}

#Preview {
    NavigationStack {
        PrivacyVisibilityView()
    }
    .environment(UserProfileViewModel())
}
