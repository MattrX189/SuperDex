//
//  OnboardingLinksStep.swift
//  SuperDex
//

import SwiftUI

struct OnboardingLinksStep: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    let accent: Color
    let onBack: () -> Void
    let onNext: () -> Void

    @FocusState private var focusedLink: ProfileLink?
    @State private var showWhatsappCountryPicker = false

    private let topLinks: [ProfileLink] = [
        .whatsapp, .instagram, .linkedin, .x, .github, .youtube, .telegram, .snapchat
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                    .padding(.top, 16)

                ForEach(topLinks, id: \.self) { link in
                    if link == .whatsapp {
                        whatsappField
                    } else {
                        linkField(for: link)
                    }
                }

                HStack(spacing: 14) {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.gilroy(.semiBold, size: 17))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)

                    Button(action: onNext) {
                        Text("Next")
                            .font(.gilroy(.semiBold, size: 17))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background {
                                Capsule().fill(.white)
                            }
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .padding(.top, 8)

                Button(action: onNext) {
                    Text("Skip for now")
                        .font(.gilroy(.medium, size: 15))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Your Links")
                .font(.gilroy(.bold, size: 26))
                .foregroundStyle(.white)

            Text("Connect your socials so people can find you. You can always update these later.")
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - WhatsApp Field (with country code)

    private static func parseWhatsapp(_ raw: String, fallbackCode: String) -> (code: String, digits: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return (fallbackCode, "") }
        if trimmed.hasPrefix("+"), let space = trimmed.firstIndex(of: " ") {
            let code = String(trimmed[..<space])
            let digits = String(trimmed[trimmed.index(after: space)...]).filter(\.isNumber)
            return (code, digits)
        }
        return (fallbackCode, trimmed.filter(\.isNumber))
    }

    private static func composeWhatsapp(code: String, digits: String) -> String {
        digits.isEmpty ? "" : "\(code) \(digits)"
    }

    private var whatsappField: some View {
        let parsed = Self.parseWhatsapp(
            viewModel.profile.links[ProfileLink.whatsapp.rawValue] ?? "",
            fallbackCode: viewModel.profile.countryCode
        )

        let codeBinding = Binding<String>(
            get: { parsed.code },
            set: { newCode in
                viewModel.profile.links[ProfileLink.whatsapp.rawValue] =
                    Self.composeWhatsapp(code: newCode, digits: parsed.digits)
            }
        )
        let digitsBinding = Binding<String>(
            get: { parsed.digits },
            set: { newDigits in
                let filtered = newDigits.filter(\.isNumber)
                viewModel.profile.links[ProfileLink.whatsapp.rawValue] =
                    Self.composeWhatsapp(code: parsed.code, digits: filtered)
            }
        )
        let isFocused = focusedLink == .whatsapp
        let hasValue = !parsed.digits.isEmpty

        return HStack(spacing: 12) {
            linkIcon(for: .whatsapp, hasValue: hasValue)

            Button {
                showWhatsappCountryPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(CountryCode.flag(for: parsed.code))
                    Text(parsed.code)
                        .font(.gilroy(.semiBold, size: 14))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showWhatsappCountryPicker) {
                CountryCodePicker(selected: codeBinding)
            }

            ZStack(alignment: .leading) {
                if digitsBinding.wrappedValue.isEmpty {
                    Text("WhatsApp number")
                        .font(.gilroy(.regular, size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: digitsBinding)
                    .font(.gilroy(.regular, size: 15))
                    .foregroundStyle(.white)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedLink, equals: .whatsapp)
                    .tint(.white)
            }

            if hasValue {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 16))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(fieldBackground(focused: isFocused))
        .animation(.easeInOut(duration: 0.2), value: hasValue)
    }

    // MARK: - Link Field

    private func linkField(for link: ProfileLink) -> some View {
        let binding = Binding<String>(
            get: { viewModel.profile.links[link.rawValue] ?? "" },
            set: { viewModel.profile.links[link.rawValue] = $0 }
        )
        let isFocused = focusedLink == link
        let hasValue = !(viewModel.profile.links[link.rawValue] ?? "").isEmpty

        return HStack(spacing: 12) {
            linkIcon(for: link, hasValue: hasValue)

            ZStack(alignment: .leading) {
                if binding.wrappedValue.isEmpty {
                    Text(link.inputPlaceholder)
                        .font(.gilroy(.regular, size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: binding)
                    .font(.gilroy(.regular, size: 15))
                    .foregroundStyle(.white)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedLink, equals: link)
                    .tint(.white)
            }

            if hasValue {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 16))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(fieldBackground(focused: isFocused))
        .animation(.easeInOut(duration: 0.2), value: hasValue)
    }

    @ViewBuilder
    private func linkIcon(for link: ProfileLink, hasValue: Bool) -> some View {
        if let brandName = link.brandIconName {
            BrandIcon(name: brandName)
                .frame(width: 20, height: 20)
                .foregroundStyle(hasValue ? accent : .white.opacity(0.55))
        } else {
            Image(systemName: link.fallbackSymbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(hasValue ? accent : .white.opacity(0.55))
                .frame(width: 20)
        }
    }

    // MARK: - Field Background

    private func fieldBackground(focused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        focused ? accent.opacity(0.7) : .white.opacity(0.10),
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focused)
    }
}
