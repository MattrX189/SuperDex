//
//  PaywallSheet.swift
//  SuperDex
//
//  Fully custom SuperDex paywall. Black & indigo design language.
//
//      .paywallSheet(isPresented: $showPaywall)
//      .presentPaywallIfNeeded(isPresented: $showPaywall)
//

import SwiftUI
import RevenueCat

// MARK: - Public modifiers

extension View {
    /// Present the custom SuperDex paywall as a sheet.
    func paywallSheet(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) { PaywallSheet() }
    }

    /// Show the paywall only when the user is **not** Pro.
    func presentPaywallIfNeeded(isPresented: Binding<Bool>) -> some View {
        modifier(PresentPaywallIfNeededModifier(isPresented: isPresented))
    }
}

private struct PresentPaywallIfNeededModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Environment(SubscriptionManager.self) private var subscription

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, requested in
                if requested && subscription.isPro { isPresented = false }
            }
            .sheet(isPresented: $isPresented) { PaywallSheet() }
    }
}

// MARK: - Sheet wrapper

struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscription

    var body: some View {
        SuperDexPaywallView(onClose: { dismiss() })
            .onChange(of: subscription.isPro) { _, isPro in
                if isPro { dismiss() }
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
            .preferredColorScheme(.dark)
    }
}

// MARK: - The custom paywall

private let indigo = Color(red: 0.35, green: 0.34, blue: 0.85)
private let indigoDark = Color(red: 0.28, green: 0.27, blue: 0.72)
private let indigoLight = Color(red: 0.48, green: 0.46, blue: 0.95)

struct SuperDexPaywallView: View {
    var onClose: () -> Void = {}

    @Environment(SubscriptionManager.self) private var subscription
    @State private var selectedPackage: Package?
    @State private var toastMessage: String?
    @State private var showPendingApproval = false

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    header.padding(.top, 12)
                    featuresSection
                    plansSection
                    purchaseButton
                    footerLinks.padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)

            VStack { topBar; Spacer() }

            if let toast = toastMessage {
                VStack {
                    Spacer()
                    toastView(toast).padding(.bottom, 28)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .alert(item: Binding(
            get: { subscription.lastError },
            set: { subscription.lastError = $0 }
        )) { err in
            Alert(title: Text(err.title), message: Text(err.message), dismissButton: .default(Text("OK")))
        }
        .alert("Approval Pending", isPresented: $showPendingApproval) {
            Button("Got it") {}
        } message: {
            Text("Your payment is awaiting approval. Please complete the autopay setup in your UPI or banking app — SuperDex Pro will activate automatically once your bank confirms. This can take a few minutes.")
        }
        .task {
            await subscription.refresh()
            if selectedPackage == nil { selectedPackage = defaultPackage() }
        }
        .onChange(of: subscription.currentOffering?.identifier) { _, _ in
            if selectedPackage == nil { selectedPackage = defaultPackage() }
        }
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.03, green: 0.03, blue: 0.06),
                    Color(red: 0.01, green: 0.01, blue: 0.03)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [indigo.opacity(0.20), .clear],
                center: UnitPoint(x: 0.5, y: 0.0), startRadius: 0, endRadius: 400
            )
            .blendMode(.plusLighter)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.gilroy(.semiBold, size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 18) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: indigo.opacity(0.50), radius: 24, y: 10)

            VStack(spacing: 10) {
                Image("SuperDexProText")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)

                Text("Unlock the full SuperDex experience.")
                    .font(.gilroy(.medium, size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("WHAT YOU GET")
            VStack(spacing: 10) {
                FeatureRow(icon: "link", title: "Custom link with your heading",
                           subtitle: "Anything from a project to a portfolio.")
                FeatureRow(icon: "pin.fill", title: "Pin up to 4 links on your card",
                           subtitle: "Pick exactly what people see first.")
                FeatureRow(icon: "photo.on.rectangle.angled", title: "Portfolio: up to 6 images",
                           subtitle: "Each image can attach its own link.")
                FeatureRow(icon: "eye.slash.fill", title: "Privacy controls",
                           subtitle: "Choose exactly what you share.")
                FeatureRow(icon: "person.2.fill", title: "Get discovered by others",
                           subtitle: "Appear in the Discover tab for all Pro members.")
                FeatureRow(icon: "eye.fill", title: "See who viewed your card",
                           subtitle: "Track new networking opportunities.")
                FeatureRow(icon: "square.and.arrow.up.fill", title: "Share your QR as an image",
                           subtitle: "Post it anywhere or send it instantly.")
                FeatureRow(icon: "qrcode.viewfinder", title: "Scan QR from Photos",
                           subtitle: "Import a code straight from your library.")
                FeatureRow(icon: "sparkles", title: "Early access to new features",
                           subtitle: "Be first to try whatever we ship next.")
            }
        }
    }

    // MARK: Plans

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("CHOOSE YOUR PLAN")
            VStack(spacing: 10) {
                if let packages = subscription.currentOffering?.availablePackages, !packages.isEmpty {
                    ForEach(orderedPackages(packages), id: \.identifier) { pkg in
                        PlanRow(
                            package: pkg,
                            isSelected: selectedPackage?.identifier == pkg.identifier,
                            isBestValue: isBestValue(pkg, in: packages),
                            savingsText: savingsText(for: pkg, in: packages)
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedPackage = pkg
                            }
                        }
                    }
                } else {
                    loadingPlans
                }
            }
        }
    }

    private var loadingPlans: some View {
        VStack(spacing: 10) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    )
                    .frame(height: 78)
                    .overlay { ProgressView().tint(.white.opacity(0.6)) }
            }
        }
    }

    // MARK: Purchase button

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button { Task { await buy() } } label: {
                ZStack {
                    brandGradient
                    if subscription.isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 10) {
                            Text(ctaTitle).font(.gilroy(.bold, size: 16))
                            Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: indigo.opacity(0.35), radius: 18, y: 10)
                .opacity(selectedPackage == nil ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(selectedPackage == nil || subscription.isProcessing)

            if let renewalCopy {
                Text(renewalCopy)
                    .font(.gilroy(.regular, size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    private var ctaTitle: String {
        guard let pkg = selectedPackage else { return "Continue" }
        if pkg.storeProduct.introductoryDiscount != nil { return "Start Free Trial" }
        return "Continue with \(shortLabel(for: pkg))"
    }

    private var renewalCopy: String? {
        guard let pkg = selectedPackage else { return nil }
        let price = pkg.storeProduct.localizedPriceString
        switch pkg.packageType {
        case .annual:  return "Billed \(price) / year. Auto-renews. Cancel anytime."
        case .monthly: return "Billed \(price) / month. Auto-renews. Cancel anytime."
        case .weekly:  return "Billed \(price) / week. Auto-renews. Cancel anytime."
        default:       return "Billed \(price). Auto-renews. Cancel anytime."
        }
    }

    // MARK: Footer

    private var footerLinks: some View {
        VStack(spacing: 14) {
            Button { Task { await restore() } } label: {
                Text("Restore Purchases")
                    .font(.gilroy(.semiBold, size: 13))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
            .disabled(subscription.isProcessing)

            HStack(spacing: 18) {
                Link("Terms of Use", destination: RevenueCatConfig.termsURL)
                Text("·")
                Link("Privacy Policy", destination: RevenueCatConfig.privacyURL)
            }
            .font(.gilroy(.regular, size: 11))
            .foregroundStyle(.white.opacity(0.45))
            .tint(.white.opacity(0.45))
        }
    }

    // MARK: Helpers

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [indigoDark, indigoLight],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.gilroy(.semiBold, size: 11))
            .tracking(1.8)
            .foregroundStyle(.white.opacity(0.55))
            .padding(.horizontal, 4)
    }

    private func toastView(_ message: String) -> some View {
        Text(message)
            .font(.gilroy(.medium, size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
            .padding(.horizontal, 24)
    }

    private func defaultPackage() -> Package? {
        let packages = subscription.currentOffering?.availablePackages ?? []
        return packages.first(where: { $0.packageType == .annual }) ?? packages.first
    }

    private func orderedPackages(_ packages: [Package]) -> [Package] {
        let order: [PackageType] = [.annual, .sixMonth, .threeMonth, .twoMonth, .monthly, .weekly]
        return packages.sorted { a, b in
            (order.firstIndex(of: a.packageType) ?? .max) < (order.firstIndex(of: b.packageType) ?? .max)
        }
    }

    private func isBestValue(_ pkg: Package, in packages: [Package]) -> Bool {
        packages.count > 1 && pkg.packageType == .annual
    }

    private func savingsText(for pkg: Package, in packages: [Package]) -> String? {
        guard pkg.packageType == .annual,
              let monthly = packages.first(where: { $0.packageType == .monthly })
        else { return nil }
        let yearlyTotal = NSDecimalNumber(decimal: pkg.storeProduct.price).doubleValue
        let monthlyTotal = NSDecimalNumber(decimal: monthly.storeProduct.price).doubleValue * 12
        guard monthlyTotal > 0, yearlyTotal < monthlyTotal else { return nil }
        let savings = Int(((monthlyTotal - yearlyTotal) / monthlyTotal) * 100)
        guard savings > 0 else { return nil }
        return "Save \(savings)%"
    }

    private func shortLabel(for pkg: Package) -> String {
        switch pkg.packageType {
        case .annual:  return "Annual"
        case .monthly: return "Monthly"
        case .weekly:  return "Weekly"
        default:       return "Pro"
        }
    }

    private func buy() async {
        guard let pkg = selectedPackage else { return }
        let granted = await subscription.purchase(pkg)
        if !granted && subscription.isPaymentPending {
            showPendingApproval = true
        }
    }

    private func restore() async {
        let ok = await subscription.restore()
        await showToast(ok ? "Purchases restored." : "No active subscription found.")
    }

    @MainActor
    private func showToast(_ message: String) async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toastMessage = message }
        try? await Task.sleep(nanoseconds: 2_400_000_000)
        withAnimation(.easeInOut(duration: 0.2)) { toastMessage = nil }
    }
}

// MARK: - Feature row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                indigo.opacity(0.30),
                                indigoDark.opacity(0.20)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: icon)
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.gilroy(.semiBold, size: 14)).foregroundStyle(.white)
                Text(subtitle)
                    .font(.gilroy(.regular, size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Plan row

private struct PlanRow: View {
    let package: Package
    let isSelected: Bool
    let isBestValue: Bool
    let savingsText: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                radio
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.gilroy(.bold, size: 15)).foregroundStyle(.white)
                        if isBestValue { bestValueBadge }
                    }
                    Text(subtitle)
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.gilroy(.bold, size: 15))
                        .foregroundStyle(.white)
                    if let savings = savingsText {
                        Text(savings)
                            .font(.gilroy(.semiBold, size: 10))
                            .foregroundStyle(Color(red: 0.55, green: 1.0, blue: 0.65))
                    } else if let perMonth = perMonthString {
                        Text(perMonth)
                            .font(.gilroy(.regular, size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected
                        ? indigo.opacity(0.90)
                        : Color.white.opacity(0.10),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelected)
    }

    private var radio: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? Color.clear : Color.white.opacity(0.25),
                    lineWidth: 1.5
                )
                .background(
                    Circle().fill(
                        isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [indigoDark, indigoLight],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                        : AnyShapeStyle(Color.clear)
                    )
                )
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var bestValueBadge: some View {
        Text("BEST VALUE")
            .font(.gilroy(.bold, size: 9))
            .tracking(1.0)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [indigoDark, indigoLight],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            )
    }

    private var title: String {
        switch package.packageType {
        case .annual:     return "Annual"
        case .monthly:    return "Monthly"
        case .weekly:     return "Weekly"
        case .sixMonth:   return "6 Months"
        case .threeMonth: return "3 Months"
        case .twoMonth:   return "2 Months"
        case .lifetime:   return "Lifetime"
        default:          return package.storeProduct.localizedTitle.isEmpty ? "Pro" : package.storeProduct.localizedTitle
        }
    }

    private var subtitle: String {
        switch package.packageType {
        case .annual:   return "Best value, billed yearly"
        case .monthly:  return "Flexible, billed monthly"
        case .weekly:   return "Billed weekly"
        case .lifetime: return "One-time payment"
        default:        return "Billed periodically"
        }
    }

    private var perMonthString: String? {
        guard package.packageType == .annual else { return nil }
        let yearly = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue
        guard yearly > 0 else { return nil }
        let perMonth = yearly / 12.0
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = package.storeProduct.priceFormatter?.locale ?? Locale.current
        return fmt.string(from: NSNumber(value: perMonth)).map { "\($0) / month" }
    }
}
