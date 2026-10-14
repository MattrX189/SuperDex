//
//  EditProfileView.swift
//  HomeScreen
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Binding var profile: UserProfileData
    let onSave: () -> Void
    var userId: UUID?
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: Field?
    private enum Field: Hashable {
        case name, username, company, jobRole, bio, phone, email
        case businessPhone, businessWhatsapp, businessEmail
        case link(String)
        case portfolioLink(Int)
    }

    @State private var showCountryPicker = false
    @State private var showWhatsappCountryPicker = false
    @State private var showBusinessPhoneCountryPicker = false
    @State private var showBusinessWhatsappCountryPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingImage = false
    @State private var uploadError: String?
    @State private var showModerationAlert = false

    private static let memojis: [String] = Avatar.allMemojis
    private let storageService = PortfolioStorageService()
    private let accent = Color.indigo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    memojiPicker
                        .padding(.top, 8)

                    personalSection
                    categoriesSection
                    contactSection
                    businessContactSection
                    socialMediaSection
                    businessSection

                    premiumSection

                    themeSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.gilroy(.medium, size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { attemptSave() }
                        .font(.gilroy(.semiBold, size: 16))
                        .foregroundStyle(.white)
                }
            }
            .preferredColorScheme(.dark)
            .alert("Upload Failed", isPresented: Binding(
                get: { uploadError != nil },
                set: { if !$0 { uploadError = nil } }
            )) {
                Button("OK") { uploadError = nil }
            } message: {
                Text(uploadError ?? "")
            }
            .alert("Let's keep it professional", isPresented: $showModerationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your profile contains language that isn't allowed on SuperDex. Please remove any offensive or inappropriate content and try again.")
            }
        }
    }

    // MARK: - Save with content moderation

    /// Blocks the save if any user-entered text field contains objectionable
    /// content — the proactive filter required by App Store Guideline 1.2.
    private func attemptSave() {
        let objectionable = ContentModeration.containsObjectionable(
            profile.firstName,
            profile.lastName,
            profile.username,
            profile.companyName,
            profile.jobRole,
            profile.bio,
            profile.customLinkTitle
        )
        guard !objectionable else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showModerationAlert = true
            return
        }
        onSave()
    }

    // MARK: - Memoji Picker

    private var memojiPicker: some View {
        VStack(spacing: 14) {
            Image(profile.avatar)
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
                        let isSelected = profile.avatar == name
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
                            .onTapGesture { profile.avatar = name }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(glassBackground())
    }

    // MARK: - Premium Section

    private let proAccent = Color(red: 0.294, green: 0.271, blue: 0.875) // #4B45DF

    private var premiumSection: some View {
        VStack(spacing: 24) {
            privacyEntryRow
            pinnedLinksSection

            if !profile.hasPro {
                UpgradeToProCard()
            }

            portfolioSection
        }
        .padding(16)
        .padding(.top, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(proAccent.opacity(0.6), lineWidth: 1.5)
        )
        .overlay(alignment: .top) {
            Image("SuperDexProText")
                .resizable()
                .scaledToFit()
                .frame(height: 16)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(red: 0.06, green: 0.06, blue: 0.10))
                )
                .offset(y: -12)
        }
    }

    // MARK: - Privacy entry

    @ViewBuilder
    private var privacyEntryRow: some View {
        if profile.hasPro {
            NavigationLink {
                PrivacyVisibilityView()
            } label: {
                privacyRowContent(isLocked: false)
            }
            .buttonStyle(.plain)
        } else {
            privacyRowContent(isLocked: true)
                .opacity(0.6)
        }
    }

    private func privacyRowContent(isLocked: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.18))
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("Privacy & Visibility")
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)
                Text("Choose what others can see")
                    .font(.gilroy(.medium, size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(glassBackground())
    }

    // MARK: - Personal

    private var personalSection: some View {
        formSection(title: "PERSONAL") {
            VStack(spacing: 0) {
                glassField(icon: "person.fill", placeholder: "First Name", text: $profile.firstName, field: .name)
                glassDivider
                glassField(icon: "person.fill", placeholder: "Last Name", text: $profile.lastName, field: .name)
                glassDivider
                usernameRow
                glassDivider
                glassField(icon: "building.2.fill", placeholder: "Company Name", text: $profile.companyName, field: .company)
                glassDivider
                glassField(icon: "briefcase.fill", placeholder: "Job Role", text: $profile.jobRole, field: .jobRole)
                glassDivider
                glassField(icon: "text.quote", placeholder: "Bio", text: $profile.bio, field: .bio)
            }
            .background(glassBackground())
        }
    }

    private var usernameRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "at")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22)

            Text(profile.username.isEmpty ? "No username" : profile.username)
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white.opacity(0.45))

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        formSection(title: "YOUR DOMAIN") {
            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ProfileCategory.allCases) { category in
                    let isSelected = profile.categories.contains(category)
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            if let idx = profile.categories.firstIndex(of: category) {
                                profile.categories.remove(at: idx)
                            } else {
                                profile.categories.append(category)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isSelected ? accent : .white.opacity(0.55))
                                .frame(width: 20)

                            Text(category.displayName)
                                .font(.gilroy(.semiBold, size: 12))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? accent.opacity(0.12) : .white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isSelected ? accent.opacity(0.5) : .white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(glassBackground())
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        formSection(title: "CONTACT") {
            VStack(spacing: 0) {
                phoneRow
                glassDivider
                whatsappRow
                glassDivider
                glassField(icon: "envelope.fill", placeholder: "Email", text: $profile.email, field: .email, keyboard: .emailAddress)
            }
            .background(glassBackground())
        }
    }

    private var phoneRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22)

            Button {
                showCountryPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(CountryCode.flag(for: profile.countryCode))
                    Text(profile.countryCode)
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
                CountryCodePicker(selected: $profile.countryCode)
            }

            ZStack(alignment: .leading) {
                if profile.phone.isEmpty {
                    Text("Phone number")
                        .font(.gilroy(.regular, size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: $profile.phone)
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
    }

    // MARK: - Business Contact

    private var businessContactSection: some View {
        formSection(title: "BUSINESS CONTACT") {
            VStack(spacing: 0) {
                businessPhoneRow
                glassDivider
                businessWhatsappRow
                glassDivider
                glassField(
                    icon: "envelope.fill",
                    placeholder: "Business Email",
                    text: Binding(
                        get: { profile.businessEmail },
                        set: { profile.businessEmail = $0 }
                    ),
                    field: .businessEmail,
                    keyboard: .emailAddress
                )
            }
            .background(glassBackground())
        }
    }

    private var businessPhoneRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22)

            Button {
                showBusinessPhoneCountryPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(CountryCode.flag(for: profile.businessCountryCode))
                    Text(profile.businessCountryCode)
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
            .sheet(isPresented: $showBusinessPhoneCountryPicker) {
                CountryCodePicker(selected: Binding(
                    get: { profile.businessCountryCode },
                    set: { profile.businessCountryCode = $0 }
                ))
            }

            ZStack(alignment: .leading) {
                if profile.businessPhone.isEmpty {
                    Text("Business phone")
                        .font(.gilroy(.regular, size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: Binding(
                    get: { profile.businessPhone },
                    set: { profile.businessPhone = $0 }
                ))
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .businessPhone)
                .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var businessWhatsappRow: some View {
        HStack(spacing: 12) {
            BrandIcon(name: "whatsapp")
                .frame(width: 20, height: 20)
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22)

            Button {
                showBusinessWhatsappCountryPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(CountryCode.flag(for: profile.businessWhatsappCountryCode))
                    Text(profile.businessWhatsappCountryCode)
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
            .sheet(isPresented: $showBusinessWhatsappCountryPicker) {
                CountryCodePicker(selected: Binding(
                    get: { profile.businessWhatsappCountryCode },
                    set: { profile.businessWhatsappCountryCode = $0 }
                ))
            }

            ZStack(alignment: .leading) {
                if profile.businessWhatsapp.isEmpty {
                    Text("Business WhatsApp")
                        .font(.gilroy(.regular, size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: Binding(
                    get: { profile.businessWhatsapp },
                    set: { profile.businessWhatsapp = $0.filter(\.isNumber) }
                ))
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white)
                .keyboardType(.phonePad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .businessWhatsapp)
                .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Social Media

    private var socialMediaSection: some View {
        formSection(title: "SOCIAL MEDIA") {
            VStack(spacing: 0) {
                // WhatsApp now lives in the Contact section.
                ForEach(Array(ProfileLink.socialOrder.filter { $0 != .whatsapp }.enumerated()), id: \.element) { index, link in
                    if index > 0 { glassDivider }
                    glassLinkField(for: link)
                }
            }
            .background(glassBackground())
        }
    }

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

    private var whatsappRow: some View {
        let parsed = Self.parseWhatsapp(
            profile.links[ProfileLink.whatsapp.rawValue] ?? "",
            fallbackCode: profile.whatsappCountryCode
        )
        let codeBinding = Binding<String>(
            get: { profile.whatsappCountryCode },
            set: { newCode in
                profile.whatsappCountryCode = newCode
                profile.links[ProfileLink.whatsapp.rawValue] =
                    Self.composeWhatsapp(code: newCode, digits: parsed.digits)
            }
        )
        let digitsBinding = Binding<String>(
            get: { parsed.digits },
            set: { newDigits in
                let filtered = newDigits.filter(\.isNumber)
                profile.links[ProfileLink.whatsapp.rawValue] =
                    Self.composeWhatsapp(code: profile.whatsappCountryCode, digits: filtered)
            }
        )

        return HStack(spacing: 12) {
            BrandIcon(name: "whatsapp")
                .frame(width: 20, height: 20)
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22)

            Button {
                showWhatsappCountryPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(CountryCode.flag(for: profile.whatsappCountryCode))
                    Text(profile.whatsappCountryCode)
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
                CountryCodePicker(selected: codeBinding)
            }

            ZStack(alignment: .leading) {
                if digitsBinding.wrappedValue.isEmpty {
                    Text("WhatsApp number")
                        .font(.gilroy(.regular, size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: digitsBinding)
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .link(ProfileLink.whatsapp.rawValue))
                    .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Business

    private var businessSection: some View {
        formSection(title: "BUSINESS") {
            VStack(spacing: 0) {
                let links = ProfileLink.businessOrder
                ForEach(Array(links.enumerated()), id: \.element) { index, link in
                    if index > 0 { glassDivider }
                    if link == .customLink {
                        VStack(spacing: 0) {
                            glassField(icon: "tag.fill", placeholder: "Custom Link Title", text: $profile.customLinkTitle, field: .link("customLinkTitle"))
                            glassDivider
                            glassLinkField(for: link)
                        }
                        .disabled(!profile.hasPro)
                        .opacity(profile.hasPro ? 1 : 0.55)
                        .overlay(alignment: .trailing) {
                            if !profile.hasPro {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .padding(.trailing, 16)
                            }
                        }
                    } else {
                        glassLinkField(for: link)
                    }
                }
            }
            .background(glassBackground())
        }
    }

    // MARK: - Pinned Links (Premium)

    private var pinnedLinksSection: some View {
        let filledLinks = ProfileLink.allCases.filter { link in
            guard let value = profile.links[link.rawValue] else { return false }
            return !value.isEmpty
        }
        let isLocked = !profile.hasPro

        return formSection(title: "PINNED LINKS ON CARD") {
            VStack(alignment: .leading, spacing: 0) {
                if filledLinks.isEmpty {
                    Text("Add links above to pin them here")
                        .font(.gilroy(.regular, size: 14))
                        .foregroundStyle(.white.opacity(0.40))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    Text("Select up to \(kMaxDisplayedLinks) links to display on your profile card.")
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.40))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    ForEach(Array(filledLinks.enumerated()), id: \.element) { index, link in
                        if index > 0 { glassDivider }
                        pinnedLinkRow(link: link)
                    }
                }
            }
            .background(glassBackground())
            .disabled(isLocked)
            .opacity(isLocked ? 0.55 : 1)
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(12)
                }
            }
        }
    }

    private func pinnedLinkRow(link: ProfileLink) -> some View {
        let key = link.rawValue
        let isPinned = profile.pinnedLinks.contains(key)

        return Button {
            togglePin(key)
        } label: {
            HStack(spacing: 12) {
                if let brandName = link.brandIconName {
                    BrandIcon(name: brandName)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(isPinned ? accent : .white.opacity(0.55))
                        .frame(width: 22)
                } else {
                    Image(systemName: link.fallbackSymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isPinned ? accent : .white.opacity(0.55))
                        .frame(width: 22)
                }

                Text(link.displayName)
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)

                Text(link.category.title)
                    .font(.gilroy(.medium, size: 10))
                    .foregroundStyle(.white.opacity(0.50))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.08)))

                Spacer()

                Image(systemName: isPinned ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isPinned ? .green : .white.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(!isPinned && profile.pinnedLinks.count >= kMaxDisplayedLinks)
    }

    // MARK: - Portfolio (Premium)

    @ViewBuilder
    private var portfolioSection: some View {
        if profile.hasPro {
            unlockedPortfolioSection
        } else {
            lockedPortfolioSection
        }
    }

    private var lockedPortfolioSection: some View {
        formSection(title: "PORTFOLIO") {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Showcase up to 6 portfolio images")
                        .font(.gilroy(.semiBold, size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Available on Pro")
                        .font(.gilroy(.medium, size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(glassBackground())
            .opacity(0.75)
        }
    }

    private var unlockedPortfolioSection: some View {
        formSection(title: "PORTFOLIO (\(profile.portfolioImages.count)/6)") {
            VStack(spacing: 0) {
                ForEach(Array(profile.portfolioImages.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { glassDivider }
                    portfolioRow(item: item, index: index)
                }

                if profile.portfolioImages.count < 6 {
                    if !profile.portfolioImages.isEmpty { glassDivider }
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(accent)
                            Text(isUploadingImage ? "Uploading..." : "Add Portfolio Image")
                                .font(.gilroy(.semiBold, size: 15))
                                .foregroundStyle(.white.opacity(0.7))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .disabled(isUploadingImage)
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        guard let newItem else { return }
                        Task { await uploadPortfolioImage(item: newItem) }
                        selectedPhotoItem = nil
                    }
                }
            }
            .background(glassBackground())
        }
    }

    private func portfolioRow(item: PortfolioImage, index: Int) -> some View {
        HStack(spacing: 12) {
            if let url = URL(string: item.imageURL), !item.imageURL.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView().tint(.white)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.3))
                    )
            }

            ZStack(alignment: .leading) {
                if profile.portfolioImages[index].linkURL.isEmpty {
                    Text("Attached link URL")
                        .font(.gilroy(.regular, size: 13))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: portfolioLinkBinding(at: index))
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .portfolioLink(index))
                    .tint(.white)
            }

            Button(role: .destructive) {
                let removed = profile.portfolioImages.remove(at: index)
                if !removed.imageURL.isEmpty {
                    Task { try? await storageService.delete(path: removed.imageURL) }
                }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Theme

    private var themeSection: some View {
        formSection(title: "THEME") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(0..<CardTheme.themes.count, id: \.self) { index in
                        let theme = CardTheme.themes[index]
                        let isSelected = profile.themeIndex == index
                        VStack(spacing: 8) {
                            ThemePreviewCard(
                                profile: profile,
                                theme: theme,
                                isSelected: isSelected
                            )
                            Text(theme.name)
                                .font(.gilroy(.semiBold, size: 11))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
                        }
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                profile.themeIndex = index
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(glassBackground())
        }
    }

    // MARK: - Shared Field Components

    private func glassField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default
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
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func glassLinkField(for link: ProfileLink) -> some View {
        let binding = Binding<String>(
            get: { profile.links[link.rawValue] ?? "" },
            set: { profile.links[link.rawValue] = $0 }
        )
        let field = Field.link(link.rawValue)

        return HStack(spacing: 12) {
            if let brandName = link.brandIconName {
                BrandIcon(name: brandName)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 22)
            } else {
                Image(systemName: link.fallbackSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 22)
            }

            ZStack(alignment: .leading) {
                if binding.wrappedValue.isEmpty {
                    Text(link.inputPlaceholder)
                        .font(.gilroy(.regular, size: 15))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: binding)
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .tint(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Section Helper

    private func formSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.gilroy(.semiBold, size: 11))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 4)

            content()
        }
    }

    // MARK: - Glass Styling

    private func glassBackground() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var glassDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 50)
    }

    // MARK: - Helpers

    private func linkBinding(for link: ProfileLink) -> Binding<String> {
        Binding(
            get: { profile.links[link.rawValue] ?? "" },
            set: { profile.links[link.rawValue] = $0 }
        )
    }

    private func portfolioLinkBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { profile.portfolioImages[index].linkURL },
            set: { profile.portfolioImages[index].linkURL = $0 }
        )
    }

    private func togglePin(_ key: String) {
        if let idx = profile.pinnedLinks.firstIndex(of: key) {
            profile.pinnedLinks.remove(at: idx)
        } else if profile.pinnedLinks.count < kMaxDisplayedLinks {
            profile.pinnedLinks.append(key)
        }
    }

    @MainActor
    private func uploadPortfolioImage(item: PhotosPickerItem) async {
        isUploadingImage = true
        defer { isUploadingImage = false }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }

        guard let uid = userId else { return }

        do {
            let url = try await storageService.upload(image: uiImage, userId: uid)
            var entry = PortfolioImage()
            entry.imageURL = url
            profile.portfolioImages.append(entry)
        } catch {
            uploadError = error.localizedDescription
        }
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let profile: UserProfileData
    let theme: CardTheme
    let isSelected: Bool

    private let cornerRadius: CGFloat = 18

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            background
            sheen
            content
        }
        .frame(width: 132, height: 176)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                isSelected ? Color.white : Color.white.opacity(0.18),
                lineWidth: isSelected ? 2.5 : 1
            )
        )
        .shadow(
            color: isSelected
                ? theme.accentColor.opacity(0.55)
                : .black.opacity(0.25),
            radius: isSelected ? 10 : 5,
            y: 4
        )
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var background: some View {
        ZStack {
            theme.gradientColors.first ?? .purple

            RadialGradient(
                colors: [
                    (theme.gradientColors.first ?? .purple).opacity(0.0),
                    (theme.gradientColors.first ?? .purple).opacity(0.9),
                    theme.gradientColors.dropFirst().first ?? .purple
                ],
                center: UnitPoint(x: 0.25, y: 0.0),
                startRadius: 12,
                endRadius: 180
            )

            RadialGradient(
                colors: [
                    (theme.gradientColors.last ?? .orange).opacity(0.95),
                    (theme.gradientColors.last ?? .orange).opacity(0.3),
                    .clear
                ],
                center: UnitPoint(x: 0.8, y: 0.95),
                startRadius: 0,
                endRadius: 140
            )
            .blendMode(.plusLighter)
            .opacity(0.85)
        }
    }

    private var sheen: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.18), location: 0.0),
                .init(color: .clear, location: 0.5),
                .init(color: .black.opacity(0.18), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            Image(profile.avatar)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            Spacer().frame(height: 8)

            Text(profile.fullName.isEmpty ? "Your Name" : profile.fullName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 8)

            Spacer().frame(height: 2)

            Text((profile.jobRole.isEmpty ? "Job Role" : profile.jobRole).uppercased())
                .font(.system(size: 7, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .padding(.horizontal, 8)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                miniGlassIcon("phone.fill")
                miniGlassIcon("envelope.fill")
            }

            Spacer(minLength: 14)
        }
        .environment(\.colorScheme, .light)
    }

    private func miniGlassIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(.white.opacity(0.18), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
    }
}

// MARK: - Edit Field (kept for backward compatibility)

struct EditField: View {
    let label: String
    @Binding var text: String
    let icon: String
    var brandIcon: String? = nil
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            if let brandIcon {
                BrandIcon(name: brandIcon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .frame(width: 24)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            TextField(label, text: $text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}
