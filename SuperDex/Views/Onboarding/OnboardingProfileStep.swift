//
//  OnboardingProfileStep.swift
//  SuperDex
//

import SwiftUI

struct OnboardingProfileStep: View {
    @Environment(UserProfileViewModel.self) private var viewModel
    @Environment(AuthViewModel.self) private var auth
    let accent: Color
    let onNext: () -> Void

    @FocusState private var focusedField: Field?
    private enum Field { case username, firstName, lastName, jobTitle, company, phone, whatsapp, bio }

    enum UsernameStatus: Equatable {
        case idle
        case checking
        case available
        case taken
        case tooShort
    }

    @State private var usernameStatus: UsernameStatus = .idle
    @State private var usernameCheckTask: Task<Void, Never>?
    @State private var showCountryPicker = false

    enum PhoneStatus: Equatable { case idle, checking, available, registered }
    @State private var phoneStatus: PhoneStatus = .idle
    @State private var phoneCheckTask: Task<Void, Never>?

    // WhatsApp: defaults to the phone number; unchecking reveals a separate field.
    @State private var whatsappSameAsPhone = true
    @State private var whatsappCode = "+91"
    @State private var whatsappDigits = ""
    @State private var showWhatsappCountryPicker = false

    private static let memojis: [String] = Avatar.allMemojis
    private static let usernameAllowed: Set<Character> = Set("abcdefghijklmnopqrstuvwxyz0123456789_")
    private static let minUsernameLength = 3

    private let service = ProfileService()

    private var phoneIsValid: Bool {
        CountryCode.isValidMobile(viewModel.profile.phone, dialCode: viewModel.profile.countryCode)
    }

    private var whatsappIsValid: Bool {
        whatsappSameAsPhone || CountryCode.isValidMobile(whatsappDigits, dialCode: whatsappCode)
    }

    private var canContinue: Bool {
        usernameStatus == .available &&
        !viewModel.profile.firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        phoneIsValid &&
        phoneStatus == .available &&
        whatsappIsValid
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                    .padding(.top, 16)

                memojiPicker

                formSection(title: "USERNAME", required: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        iconField(
                            icon: "at",
                            placeholder: "Choose a username",
                            text: usernameBinding,
                            field: .username,
                            keyboard: .asciiCapable
                        )
                        usernameStatusLabel
                    }
                }

                formSection(title: "FIRST NAME", required: true) {
                    iconField(
                        icon: "person.fill",
                        placeholder: "First name",
                        text: Bindable(viewModel).profile.firstName,
                        field: .firstName,
                        keyboard: .default
                    )
                }

                formSection(title: "LAST NAME") {
                    iconField(
                        icon: "person.fill",
                        placeholder: "Last name",
                        text: Bindable(viewModel).profile.lastName,
                        field: .lastName,
                        keyboard: .default
                    )
                }

                formSection(title: "PHONE NUMBER", required: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        phoneField
                        if !viewModel.profile.phone.isEmpty && !phoneIsValid {
                            lengthHint(for: viewModel.profile.countryCode)
                        }
                        phoneStatusLabel
                        whatsappSameToggle
                        if !whatsappSameAsPhone {
                            whatsappField
                                .transition(.move(edge: .top).combined(with: .opacity))
                            if !whatsappDigits.isEmpty && !whatsappIsValid {
                                lengthHint(for: whatsappCode)
                            }
                        }
                    }
                }

                formSection(title: "JOB TITLE") {
                    iconField(
                        icon: "briefcase.fill",
                        placeholder: "e.g. Product Designer",
                        text: Bindable(viewModel).profile.jobRole,
                        field: .jobTitle,
                        keyboard: .default
                    )
                }

                formSection(title: "COMPANY") {
                    iconField(
                        icon: "building.2.fill",
                        placeholder: "e.g. Apple",
                        text: Bindable(viewModel).profile.companyName,
                        field: .company,
                        keyboard: .default
                    )
                }

                formSection(title: "BIO") {
                    bioField
                }

                Button {
                    commitWhatsapp()
                    onNext()
                } label: {
                    Text("Next")
                        .font(.gilroy(.semiBold, size: 17))
                        .foregroundStyle(canContinue ? .black : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background {
                            // Pure liquid glass until ready, then fills solid white.
                            Capsule().fill(.white.opacity(canContinue ? 1 : 0))
                        }
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                .scaleEffect(canContinue ? 1.0 : 0.97)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: canContinue)
                .disabled(!canContinue)
                .padding(.top, 8)

                Button {
                    auth.signOut()
                } label: {
                    Text("Wrong account? Sign out")
                        .font(.gilroy(.medium, size: 14))
                        .foregroundStyle(.white.opacity(0.40))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Set Up Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prefillNameFromApple()
            evaluateUsername(viewModel.profile.username)
            evaluatePhone()
            loadWhatsapp()
        }
        .onChange(of: viewModel.profile.phone) { evaluatePhone() }
        .onChange(of: viewModel.profile.countryCode) { evaluatePhone() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set Up Your Profile")
                .font(.gilroy(.bold, size: 26))
                .foregroundStyle(.white)

            Text("Pick an avatar and tell us about yourself.")
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Memoji Picker

    private var memojiPicker: some View {
        VStack(spacing: 14) {
            Image(viewModel.profile.avatar)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(accent.opacity(0.8), lineWidth: 3)
                )
                .shadow(color: accent.opacity(0.4), radius: 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Self.memojis, id: \.self) { name in
                        let isSelected = viewModel.profile.avatar == name
                        Image(name)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isSelected ? accent : .white.opacity(0.12),
                                        lineWidth: isSelected ? 2.5 : 1
                                    )
                            )
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                            .animation(.easeInOut(duration: 0.18), value: isSelected)
                            .onTapGesture { viewModel.profile.avatar = name }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(fieldBackground(focused: false))
    }

    // MARK: - Section Helper

    private func formSection<Content: View>(
        title: String,
        required: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.gilroy(.semiBold, size: 11))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.55))

                if required {
                    Text("•  REQUIRED")
                        .font(.gilroy(.semiBold, size: 10))
                        .tracking(1.2)
                        .foregroundStyle(accent.opacity(0.95))
                }

                Spacer()
            }
            .padding(.horizontal, 4)

            content()
        }
    }

    // MARK: - Icon Field

    private func iconField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22)

            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.gilroy(.regular, size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: text)
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(field == .username ? .never : .words)
                    .autocorrectionDisabled(field == .username)
                    .focused($focusedField, equals: field)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(fieldBackground(focused: focusedField == field))
    }

    // MARK: - Phone Field

    private var phoneField: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22)

            Button {
                showCountryPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(CountryCode.flag(for: viewModel.profile.countryCode))
                    Text(viewModel.profile.countryCode)
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showCountryPicker) {
                CountryCodePicker(selected: Bindable(viewModel).profile.countryCode)
            }

            ZStack(alignment: .leading) {
                if viewModel.profile.phone.isEmpty {
                    Text("Phone number")
                        .font(.gilroy(.regular, size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: Bindable(viewModel).profile.phone)
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .phone)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(fieldBackground(focused: focusedField == .phone))
    }

    private func lengthHint(for dialCode: String) -> some View {
        let country = CountryCode.all.first { $0.dial == dialCode }?.name ?? "this country"
        return statusText(
            "Enter a \(CountryCode.lengthDescription(for: dialCode)) number for \(country)",
            color: .white.opacity(0.55),
            systemImage: nil
        )
    }

    // MARK: - WhatsApp

    private var whatsappSameToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                whatsappSameAsPhone.toggle()
            }
            if !whatsappSameAsPhone {
                focusedField = .whatsapp
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: whatsappSameAsPhone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(whatsappSameAsPhone ? accent : .white.opacity(0.45))

                BrandIcon(name: "whatsapp")
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.white.opacity(0.55))

                Text("Same number on WhatsApp")
                    .font(.gilroy(.medium, size: 14))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()
            }
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var whatsappField: some View {
        HStack(spacing: 12) {
            BrandIcon(name: "whatsapp")
                .frame(width: 22, height: 18)
                .foregroundStyle(.white.opacity(0.55))

            Button {
                showWhatsappCountryPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(CountryCode.flag(for: whatsappCode))
                    Text(whatsappCode)
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showWhatsappCountryPicker) {
                CountryCodePicker(selected: $whatsappCode)
            }

            ZStack(alignment: .leading) {
                if whatsappDigits.isEmpty {
                    Text("WhatsApp number")
                        .font(.gilroy(.regular, size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: Binding(
                    get: { whatsappDigits },
                    set: { whatsappDigits = $0.filter(\.isNumber) }
                ))
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focusedField, equals: .whatsapp)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(fieldBackground(focused: focusedField == .whatsapp))
    }

    /// Restores the checkbox state when returning to this step (e.g. Back from Theme).
    private func loadWhatsapp() {
        let profile = viewModel.profile
        let stored = (profile.links[ProfileLink.whatsapp.rawValue] ?? "").trimmingCharacters(in: .whitespaces)
        let storedCode = profile.whatsappCountryCode
        var storedDigits = stored.filter(\.isNumber)
        if stored.hasPrefix("+"), let space = stored.firstIndex(of: " ") {
            storedDigits = String(stored[stored.index(after: space)...]).filter(\.isNumber)
        }

        let phoneDigits = profile.phone.filter(\.isNumber)
        if storedDigits.isEmpty || (storedDigits == phoneDigits && storedCode == profile.countryCode) {
            whatsappSameAsPhone = true
            whatsappCode = profile.countryCode
            whatsappDigits = ""
        } else {
            whatsappSameAsPhone = false
            whatsappCode = storedCode
            whatsappDigits = storedDigits
        }
    }

    /// Writes the WhatsApp number into the profile links in the same
    /// "+<code> <digits>" format EditProfileView uses.
    private func commitWhatsapp() {
        let code = whatsappSameAsPhone ? viewModel.profile.countryCode : whatsappCode
        let digits = whatsappSameAsPhone ? viewModel.profile.phone.filter(\.isNumber) : whatsappDigits
        viewModel.profile.whatsappCountryCode = code
        viewModel.profile.links[ProfileLink.whatsapp.rawValue] = digits.isEmpty ? "" : "\(code) \(digits)"
    }

    // MARK: - Bio Field

    private var bioField: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.profile.bio.isEmpty {
                Text("Tell people about yourself… (optional)")
                    .font(.gilroy(.regular, size: 15))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }

            TextEditor(text: Bindable(viewModel).profile.bio)
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($focusedField, equals: .bio)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 80)
        }
        .background(fieldBackground(focused: focusedField == .bio))
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

    // MARK: - Username Validation

    private var usernameBinding: Binding<String> {
        Binding(
            get: { viewModel.profile.username },
            set: { newValue in
                let sanitized = Self.sanitizeUsername(newValue)
                if viewModel.profile.username != sanitized {
                    viewModel.profile.username = sanitized
                }
                evaluateUsername(sanitized)
            }
        )
    }

    // MARK: - Apple name prefill

    private func prefillNameFromApple() {
        guard let name = auth.suggestedName else { return }
        if viewModel.profile.firstName.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.profile.firstName = name.first
        }
        if viewModel.profile.lastName.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.profile.lastName = name.last
        }
    }

    // MARK: - Duplicate phone check

    private func evaluatePhone() {
        phoneCheckTask?.cancel()
        guard phoneIsValid else {
            phoneStatus = .idle
            return
        }
        let code = viewModel.profile.countryCode
        let number = viewModel.profile.phone.filter(\.isNumber)
        phoneStatus = .checking
        phoneCheckTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            do {
                let registered = try await service.isPhoneRegistered(countryCode: code, number: number)
                guard !Task.isCancelled,
                      code == viewModel.profile.countryCode,
                      number == viewModel.profile.phone.filter(\.isNumber) else { return }
                phoneStatus = registered ? .registered : .available
            } catch {
                guard !Task.isCancelled else { return }
                // Don't block sign-up if the check itself fails.
                phoneStatus = .available
            }
        }
    }

    @ViewBuilder
    private var phoneStatusLabel: some View {
        switch phoneStatus {
        case .idle, .available:
            EmptyView()
        case .checking:
            statusText("Checking number…", color: .white.opacity(0.55), systemImage: nil)
        case .registered:
            VStack(alignment: .leading, spacing: 8) {
                statusText(
                    "You already have an account with this number",
                    color: .red.opacity(0.9),
                    systemImage: "exclamationmark.circle.fill"
                )
                Button {
                    auth.signOut()
                } label: {
                    Text("Sign in to that account instead")
                        .font(.gilroy(.semiBold, size: 13))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static func sanitizeUsername(_ raw: String) -> String {
        String(raw.lowercased().filter { usernameAllowed.contains($0) })
    }

    private func evaluateUsername(_ value: String) {
        usernameCheckTask?.cancel()

        if value.isEmpty {
            usernameStatus = .idle
            return
        }
        if value.count < Self.minUsernameLength {
            usernameStatus = .tooShort
            return
        }

        usernameStatus = .checking
        usernameCheckTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            guard value == viewModel.profile.username else { return }

            do {
                let taken = try await service.isUsernameTaken(value, excludingUserId: viewModel.currentUserId)
                guard !Task.isCancelled,
                      value == viewModel.profile.username else { return }

                usernameStatus = taken ? .taken : .available
            } catch {
                guard !Task.isCancelled else { return }
                usernameStatus = .idle
            }
        }
    }

    @ViewBuilder
    private var usernameStatusLabel: some View {
        switch usernameStatus {
        case .idle:
            EmptyView()
        case .checking:
            statusText("Checking availability…", color: .white.opacity(0.55), systemImage: nil)
        case .available:
            statusText("Username is available", color: .green.opacity(0.9), systemImage: "checkmark.circle.fill")
        case .taken:
            statusText("That username is taken", color: .red.opacity(0.9), systemImage: "xmark.circle.fill")
        case .tooShort:
            statusText("Must be at least \(Self.minUsernameLength) characters", color: .white.opacity(0.55), systemImage: nil)
        }
    }

    private func statusText(_ text: String, color: Color, systemImage: String?) -> some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(.gilroy(.medium, size: 12))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
    }
}
