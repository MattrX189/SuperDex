import SwiftUI

struct ProFeaturesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showManageSubscription = false

    private let pro = Color(red: 0.294, green: 0.271, blue: 0.875)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 56)
                        .padding(.bottom, 28)

                    benefitsDivider
                        .padding(.bottom, 20)

                    benefitsGrid
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)

                    manageButton
                        .padding(.bottom, 40)
                }
            }

            VStack {
                topBar
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .presentCustomerCenter(isPresented: $showManageSubscription)
    }

    // MARK: - Background (NewGroupView language)

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)

            RadialGradient(
                colors: [pro.opacity(0.30), .clear],
                center: UnitPoint(x: 0.0, y: 0.0),
                startRadius: 0,
                endRadius: 420
            )

            RadialGradient(
                colors: [pro.opacity(0.18), .clear],
                center: UnitPoint(x: 1.0, y: 0.2),
                startRadius: 0,
                endRadius: 360
            )
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: pro.opacity(0.45), radius: 24, y: 10)
                .shadow(color: .black.opacity(0.40), radius: 12, y: 6)

            Image("SuperDexProText")
                .resizable()
                .scaledToFit()
                .frame(height: 22)
        }
    }

    // MARK: - Divider

    private var benefitsDivider: some View {
        HStack(spacing: 10) {
            dividerLine
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(pro.opacity(0.8))
            Text("BENEFITS AT A GLANCE")
                .font(.gilroy(.semiBold, size: 11))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize()
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(pro.opacity(0.8))
            dividerLine
        }
        .padding(.horizontal, 20)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.0), .white.opacity(0.15), .white.opacity(0.0)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 1)
    }

    // MARK: - Benefits Grid

    private var benefitsGrid: some View {
        VStack(spacing: 12) {
            benefitCard(
                category: "ON PROFILE",
                icon: "eye.slash.fill",
                title: "Privacy Controls",
                subtitle: nil,
                fullWidth: true
            )

            HStack(spacing: 12) {
                benefitCard(
                    category: "ON PROFILE",
                    icon: "link.badge.plus",
                    title: "Add Custom Link",
                    subtitle: nil,
                    fullWidth: true
                )
                benefitCard(
                    category: "ON PROFILE",
                    icon: "pin.fill",
                    title: "Pin Any 4 Links to ProfileCard",
                    subtitle: nil
                )
//                benefitCard(
//                    category: "ON DISCOVER",
//                    icon: "person.2.fill",
//                    title: "Get Discovered",
//                    subtitle: nil
//                )
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                                
                benefitCard(
                    category: "ON PORTFOLIO",
                    icon: "photo.on.rectangle.angled",
                    title: "Showcase 6 Portfolio Images",
                    subtitle: nil
                )
                benefitCard(
                    category: "ON PROFILE",
                    icon: "person.2.fill",
                    title: "Share Selective Details via QR",
                    subtitle: nil
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                benefitCard(
                    category: "PROFILE VIEWS",
                    icon: "eye.fill",
                    title: "See Profile Views",
                    subtitle: nil
                )
                benefitCard(
                    category: "ON DISCOVER",
                    icon: "person.2.fill",
                    title: "Get Discovered",
                    subtitle: nil
                )
                
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                benefitCard(
                    category: "ON SHARING",
                    icon: "square.and.arrow.up.fill",
                    title: "Share QR as Image",
                    subtitle: nil
                )
                benefitCard(
                    category: "ON SCANNING",
                    icon: "qrcode.viewfinder",
                    title: "Scan QR from Photos",
                    subtitle: nil
                )
//                benefitCard(
//                    category: "ACROSS APP",
//                    icon: "sparkles",
//                    title: "Early Access",
//                    subtitle: nil
//                )
            }
            .fixedSize(horizontal: false, vertical: true)
            
            
            benefitCard(
                category: "ACROSS APP",
                icon: "sparkles",
                title: "Early Access",
                subtitle: nil,
                fullWidth: true
            )
        }
    }

    private func benefitCard(
        category: String,
        icon: String,
        title: String,
        subtitle: String?,
        fullWidth: Bool = false
    ) -> some View {
        VStack(spacing: fullWidth ? 12 : 10) {
            Text(category)
                .font(.gilroy(.bold, size: 11))
                .tracking(1.8)
                .foregroundStyle(Color(red: 0.70, green: 0.68, blue: 1.0))

            iconBadge(icon: icon, fullWidth: fullWidth)

            Text(title)
                .font(.gilroy(.bold, size: fullWidth ? 16 : 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.gilroy(.regular, size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fullWidth ? nil : .infinity)
        .padding(.vertical, fullWidth ? 24 : 20)
        .padding(.horizontal, 12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .compositingGroup()
        .overlay(cardHighlightBorder)
        .shadow(color: pro.opacity(0.30), radius: 18, y: 12)
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // MARK: - Card background (GroupCardView language)

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.05, green: 0.06, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [pro.opacity(0.40), .clear],
                center: UnitPoint(x: 0.0, y: 0.0),
                startRadius: 0,
                endRadius: 240
            )

            RadialGradient(
                colors: [pro.opacity(0.20), .clear],
                center: UnitPoint(x: 1.0, y: 1.1),
                startRadius: 0,
                endRadius: 200
            )

            RadialGradient(
                colors: [.white.opacity(0.10), .clear],
                center: UnitPoint(x: 0.95, y: 0.05),
                startRadius: 0,
                endRadius: 180
            )
        }
    }

    private var cardHighlightBorder: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        pro.opacity(0.55),
                        .white.opacity(0.10),
                        .clear,
                        pro.opacity(0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    // MARK: - Icon badge

    private func iconBadge(icon: String, fullWidth: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [pro, pro.opacity(0.55)],
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

            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
        .frame(width: 56, height: 56)
        .shadow(color: pro.opacity(0.55), radius: 10, y: 6)
    }

    // MARK: - Manage Button

    private var manageButton: some View {
        Button { showManageSubscription = true } label: {
            HStack(spacing: 6) {
                Text("Manage Subscription")
                    .font(.gilroy(.semiBold, size: 13))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.55))
        }
        .buttonStyle(.plain)
    }
}
