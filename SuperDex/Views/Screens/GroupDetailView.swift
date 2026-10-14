//
//  GroupDetailView.swift
//  HomeScreen
//

import SwiftUI

struct GroupDetailView: View {
    let group: CardGroup
    var onEdit: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(HomeViewModel.self) private var home
    @Environment(ContactsViewModel.self) private var contactsVM

    @State private var selectedProfile: ProfileCard?
    @Namespace private var profileNamespace
    @State private var showPickContacts = false
    @State private var isScanningForGroup = false
    @State private var scannedForGroup: ScannedForGroupPayload?
    @State private var unrecognizedScan: UnrecognizedScan?
    @State private var showEditMembers = false
    @State private var isDescriptionExpanded = false
    @State private var linkCopied = false

    private var liveGroup: CardGroup {
        home.groups.first(where: { $0.id == group.id }) ?? group
    }
    private var members: [ProfileCard] { liveGroup.profileCards }
    private var memberCount: Int { members.count }

    private var wallpaperImage: UIImage? {
        guard let data = group.wallpaperData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Color.clear.frame(height: 56)

                    heroCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, wallpaperImage == nil ? 0 : 8)

                    titleSection
                        .padding(.horizontal, 22)

                    profilesSection
                        .padding(.top, 4)
                        .padding(.bottom, 56)
                }
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await home.refreshGroupMembers(groupId: group.id)
            }

            topBar
                .padding(.horizontal, 20)
                .padding(.top, 4)
        }
        .background {
            pageBackground
                .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedProfile) { profile in
            ProfileDetailView(profile: profile)
                .navigationTransition(.zoom(sourceID: profile.id, in: profileNamespace))
        }
        .sheet(isPresented: $showPickContacts) {
            PickFromContactsSheet(group: group)
        }
        .qrScanner(isScanning: $isScanningForGroup) { code in
            if let payload = SuperDexQRPayload.decode(from: code) {
                scannedForGroup = ScannedForGroupPayload(username: payload.username)
            } else {
                unrecognizedScan = UnrecognizedScan(value: code)
            }
        }
        .sheet(item: $scannedForGroup) { wrapper in
            ScannedProfileView(scannedUsername: wrapper.username, addToGroupId: group.id)
        }
        .sheet(isPresented: $showEditMembers) {
            EditGroupMembersView(groupId: group.id, accentColor: group.color)
                .environment(home)
                .environment(contactsVM)
        }
        .alert("Unrecognized QR", isPresented: Binding(
            get: { unrecognizedScan != nil },
            set: { if !$0 { unrecognizedScan = nil } }
        ), presenting: unrecognizedScan) { _ in
            Button("OK") { unrecognizedScan = nil }
        } message: { _ in
            Text("That code isn't a SuperDex profile.")
        }
    }

    // MARK: - Page background

    @ViewBuilder
    private var pageBackground: some View {
        if let img = wallpaperImage {
            ZStack {
                Color.black

                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .blur(radius: 90, opaque: true)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.05),
                        Color.black.opacity(0.30),
                        Color.black.opacity(0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09)

                LinearGradient(
                    colors: [
                        group.color.opacity(0.55),
                        group.color.opacity(0.20),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )

                RadialGradient(
                    colors: [group.color.opacity(0.30), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 420
                )
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 10) {
                Menu {
                    Button {
                        showPickContacts = true
                    } label: {
                        Label("From Contacts", systemImage: "person.2.fill")
                    }
                    Button {
                        isScanningForGroup = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)

                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit Deck", systemImage: "pencil")
                    }

                    if !members.isEmpty {
                        Button {
                            showEditMembers = true
                        } label: {
                            Label("Edit Deck Members", systemImage: "person.2.badge.gearshape")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hero card (square, locked to its allocated width)

    private var heroCard: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            ZStack(alignment: .bottom) {
                heroBackground(side: side)

                heroForeground(side: side)

                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: side, height: 80)
                .allowsHitTesting(false)

                heroBadge
                    .frame(width: side)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.50), radius: 24, y: 14)
    }

    @ViewBuilder
    private func heroBackground(side: CGFloat) -> some View {
        if let img = wallpaperImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipped()
                .blur(radius: 40, opaque: true)
                .scaleEffect(1.08)
                .frame(width: side, height: side)
                .clipped()
                .allowsHitTesting(false)
        } else {
            ZStack {
                LinearGradient(
                    colors: [group.color, group.color.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [.white.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.2, y: 0.2),
                    startRadius: 0,
                    endRadius: 220
                )
            }
            .frame(width: side, height: side)
        }
    }

    @ViewBuilder
    private func heroForeground(side: CGFloat) -> some View {
        if let img = wallpaperImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
                .allowsHitTesting(false)
        } else {
            Image(systemName: group.icon)
                .font(.system(size: 90, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: side, height: side)
        }
    }

    private var heroBadge: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Text("\(memberCount) MEMBERS")
                .font(.gilroy(.semiBold, size: 12))
                .tracking(2.2)
                .foregroundStyle(.white)

            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(wallpaperImage != nil ? group.color.opacity(0.55) : group.color.opacity(0.45))
        .background(.ultraThinMaterial)
    }

    // MARK: - Title section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.name)
                .font(.gilroy(.bold, size: 30))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            infoChips
                .padding(.top, 4)

            if let link = groupLinkURL {
                linkRow(link)
            }

            if let desc = liveGroup.descriptionText, !desc.isEmpty {
                descriptionCard(desc)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupLinkURL: URL? {
        guard var raw = liveGroup.link?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if !raw.lowercased().hasPrefix("http") { raw = "https://" + raw }
        return URL(string: raw)
    }

    // Mirrors EventDetailView's chip row: location, date, time. The
    // member count lives in the hero badge; its chip only fills in
    // when there's no location to show.
    @ViewBuilder
    private var infoChips: some View {
        HStack(spacing: 10) {
            if let location = liveGroup.location, !location.isEmpty {
                glassChip(icon: "mappin.and.ellipse", text: location)
            } else {
                glassChip(
                    icon: "person.2.fill",
                    text: "\(memberCount) member\(memberCount == 1 ? "" : "s")"
                )
            }

            if let date = group.eventDate {
                glassChip(icon: "calendar", text: dateOnlyString(date))
                glassChip(icon: "clock", text: timeOnlyString(date))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // Mirrors EventDetailView's link row: open on tap, copy shortcut.
    private func linkRow(_ url: URL) -> some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                openURL(url)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(group.color)

                    Text(url.absoluteString)
                        .font(.gilroy(.medium, size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .padding(.horizontal, 14)
                .glassEffect(.regular.interactive(), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                UIPasteboard.general.string = url.absoluteString
                linkCopied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    linkCopied = false
                }
            } label: {
                Image(systemName: linkCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(linkCopied ? .green : .white)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    /// Rough size at which 15pt body text exceeds the collapsed
    /// 4-line limit — below this the toggle would do nothing.
    private var descriptionNeedsToggle: Bool {
        (liveGroup.descriptionText?.count ?? 0) > 180
    }

    @ViewBuilder
    private func descriptionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.gilroy(.semiBold, size: 14))
                .foregroundStyle(.white.opacity(0.45))

            Text(text)
                .font(.gilroy(.regular, size: 15))
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(3)
                .lineLimit(isDescriptionExpanded ? nil : 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if descriptionNeedsToggle {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isDescriptionExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(isDescriptionExpanded ? "Show less" : "Read more")
                            .font(.gilroy(.semiBold, size: 13))
                        Image(systemName: isDescriptionExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(group.color)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.22),
                            .white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }

    @ViewBuilder
    private func glassChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(group.color)

            Text(text)
                .font(.gilroy(.semiBold, size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .padding(.horizontal, 10)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private func dateOnlyString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func timeOnlyString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - Profiles

    @ViewBuilder
    private var profilesSection: some View {
        if liveGroup.members.isEmpty {
            emptyMembersState
                .padding(.horizontal, 24)
                .padding(.top, 12)
        } else {
            ProfileCardsView(profiles: members, selectedProfile: $selectedProfile, transitionNamespace: profileNamespace)
                .frame(height: 460)
        }
    }

    private var emptyMembersState: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Text("No members yet")
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                Text("Add contacts from the Contacts tab to see them here.")
                    .font(.gilroy(.regular, size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                emptyActionButton(
                    icon: "person.2.fill",
                    title: "From Contacts",
                    subtitle: "Pick existing"
                ) {
                    showPickContacts = true
                }

                emptyActionButton(
                    icon: "qrcode.viewfinder",
                    title: "Scan QR",
                    subtitle: "Add new card"
                ) {
                    isScanningForGroup = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func emptyActionButton(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(group.color.opacity(0.25))
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(group.color)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ScannedForGroupPayload: Identifiable {
    let id = UUID()
    let username: String
}

private struct UnrecognizedScan: Identifiable {
    let id = UUID()
    let value: String
}

#Preview {
    NavigationStack {
        GroupDetailView(
            group: CardGroup(
                name: "First Sip at RWA House",
                colorName: "purple",
                icon: "sparkles",
                descriptionText: "Join us for early morning coffee, conversations, and connections with fellow founders building the future.",
                eventDate: Date()
            )
        )
    }
    .environment(HomeViewModel())
    .environment(ContactsViewModel())
    .preferredColorScheme(.dark)
}
