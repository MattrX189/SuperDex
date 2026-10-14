//
//  ProfileQRSheet.swift
//  SuperDex
//
//  "My Card": your card, your QR and the auto-share setting on one fixed
//  page (no scrolling). The card is the same size as on the Profile tab;
//  the QR takes whatever room is left and grows to a large, easy-to-scan
//  code when tapped.
//

import SwiftUI

struct ProfileQRSheet: View {
    let profile: ProfileCard
    let username: String
    var qrCodeData: String = ""
    /// Show the card page as the sheet slides up, then grow the QR to full
    /// size on its own, ready to scan (Home → My Card).
    var magnifiesOnOpen: Bool = false

    @State private var localQRImage: UIImage?
    @State private var isQRMagnified = false
    @Namespace private var qrNamespace
    @Environment(\.dismiss) private var dismiss
    @Environment(ContactsViewModel.self) private var contactsVM

    private var qrImage: UIImage? {
        if let data = Data(base64Encoded: qrCodeData), !qrCodeData.isEmpty {
            return UIImage(data: data)
        }
        return localQRImage
    }

    private var themeColor: Color {
        profile.theme.gradientColors.first ?? .indigo
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = Layout(size: geometry.size)
            ZStack {
                background

                VStack(spacing: Layout.spacing) {
                    // Same size as the Profile tab's hero card.
                    ProfileCardView(profile: profile, showsShadow: false, allowsFlip: true)
                        .heroCardFrame()
                        .shadow(color: themeColor.opacity(0.4), radius: 24, y: 12)

                    qrRow(size: layout.qrSize)
                        .padding(.horizontal, 20)

                    autoShareToggle
                        .padding(.horizontal, 20)
                }
                .padding(.top, Layout.topInset)
                .frame(maxHeight: .infinity, alignment: .top)

                if isQRMagnified {
                    magnifiedQR(width: geometry.size.width)
                }
            }
        }
        .onAppear {
            if qrCodeData.isEmpty {
                localQRImage = QRCodeViewModel().generateQRCode(username: username)
            }
        }
        .task {
            guard magnifiesOnOpen else { return }
            // Just after the sheet finishes sliding up.
            try? await Task.sleep(for: .milliseconds(450))
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { isQRMagnified = true }
        }
    }

    // MARK: - Layout

    /// Fits everything on one screen: the card keeps its Profile-tab size and
    /// the QR shrinks to the space that's left.
    private struct Layout {
        static let topInset: CGFloat = 28
        static let spacing: CGFloat = 18
        static let toggleHeight: CGFloat = 84
        static let qrRowPadding: CGFloat = 28   // inside the QR row's card
        static let bottomInset: CGFloat = 16

        let qrSize: CGFloat

        init(size: CGSize) {
            let cardWidth = size.width - ProfileCardLayout.screenInset * 2
            let cardHeight = cardWidth / ProfileCardLayout.aspectRatio
            let used = Self.topInset + cardHeight + Self.spacing * 2 + Self.toggleHeight
                + Self.qrRowPadding + Self.bottomInset
            qrSize = min(max(size.height - used, 72), 150)
        }
    }

    // MARK: - Pieces

    private var background: some View {
        ZStack {
            AppBackground()
            RadialGradient(
                colors: [themeColor.opacity(0.35), .clear],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private func qrRow(size: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { isQRMagnified = true }
        } label: {
            HStack(spacing: 16) {
                qrCode
                    .matchedGeometryEffect(id: "qr", in: qrNamespace, isSource: !isQRMagnified)
                    .frame(width: size, height: size)
                    .opacity(isQRMagnified ? 0 : 1)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Scan to add me")
                        .font(.gilroy(.bold, size: 18))
                        .foregroundStyle(.white)
                    Text("Anyone with SuperDex can scan this to save your card.")
                        .font(.gilroy(.regular, size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Tap to enlarge", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.gilroy(.semiBold, size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your QR code. Tap to enlarge.")
    }

    /// The QR on a white tile (needed for scanners to read it).
    private var qrCode: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
            }
        }
    }

    /// Big, centered QR for scanning; tap anywhere to shrink it back.
    private func magnifiedQR(width: CGFloat) -> some View {
        let side = min(width - 64, 340)
        return ZStack {
            // Frosted and dark enough that nothing behind reads through.
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.7))
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 20) {
                Text(profile.name)
                    .font(.gilroy(.bold, size: 24))
                    .foregroundStyle(.white)
                    .transition(.opacity)

                qrCode
                    .matchedGeometryEffect(id: "qr", in: qrNamespace, isSource: isQRMagnified)
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 10)

                Text(magnifiesOnOpen ? "Tap to see your card" : "Tap anywhere to close")
                    .font(.gilroy(.medium, size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { isQRMagnified = false }
        }
        .zIndex(1)
    }

    /// When you add someone (e.g. by scanning their QR), share your card
    /// back automatically instead of being asked. Synced to the profile.
    private var autoShareToggle: some View {
        Toggle(isOn: Binding(
            get: { contactsVM.autoShareCard },
            set: { on in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                contactsVM.setAutoShareCard(on)
            }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Auto-share my card")
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)
                Text("When you add someone, they get your card too. They still choose whether to add you.")
                    .font(.gilroy(.regular, size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(themeColor)
        .padding(16)
        .frame(minHeight: Layout.toggleHeight)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            ProfileQRSheet(profile: sampleProfiles[0], username: "ben_dev")
                .environment(ContactsViewModel())
        }
}
