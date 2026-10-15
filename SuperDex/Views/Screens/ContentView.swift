//
//  ContentView.swift
//  HomeScreen
//  original 1.0.6 Code
//  Created by Gaurang Pant on 15/04/26. lastest push
//

import SwiftUI

struct ContentView: View {
    private enum TabKind: Hashable { case home, deck, discover, events, contacts, profile, scan }

    @Environment(UserProfileViewModel.self) private var profileVM
    @Environment(HomeViewModel.self) private var homeVM
    @Environment(NotificationsViewModel.self) private var notifications
    @Environment(\.isSplashShowing) private var isSplashShowing
    @State private var selectedTab: TabKind = .home
    @State private var isScanning: Bool = false
    @State private var scannedPayload: RootScannedPayload?
    @State private var unrecognizedCode: RootScannedQRCode?
    @State private var profilePath: [ProfileRoute] = []
    /// Shared by Home and Deck so both show the same events and filters.
    @State private var eventsVM = EventsViewModel()

    private enum ProfileRoute: Hashable { case privacy }

    var body: some View {
        @Bindable var viewModel = homeVM
        @Bindable var notifications = notifications
        return TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: TabKind.home) {
                HomeView()
                    .topEdgeBlur()
                //EventsView()
            }
            
            Tab("Deck", systemImage: "rectangle.stack.fill", value: TabKind.deck) {
                DeckView()
                    .topEdgeBlur()
            }

            Tab("Contacts", systemImage: "person.2.fill", value: TabKind.contacts) {
                ContactsView()
                    .topEdgeBlur()
            }
            Tab("Discover", systemImage: "globe", value: TabKind.discover) {
                DiscoverView()
                    .topEdgeBlur()

            }
//            Tab("Events", systemImage: "calendar", value: TabKind.events) {
//                EventsView()
//            }
            Tab("Profile", systemImage: "person.fill", value: TabKind.profile) {
                NavigationStack(path: $profilePath) {
                    UserProfileView(
                        profile: profileVM.profile.asProfileCard,
                        isUserProfile: true
                    )
                    .navigationDestination(for: ProfileRoute.self) { route in
                        switch route {
                        case .privacy:
                            PrivacyVisibilityView()
                        }
                    }
                }
                .topEdgeBlur()
            }
            // Scan moved to the Home quick actions (uses openScanner below).
//            Tab("Scan", systemImage: "qrcode.viewfinder", value: TabKind.scan, role: .search) {
//                Color.clear
//            }
        }
        .tint(Color(red: 0x7A / 255.0, green: 0x89 / 255.0, blue: 0xFD / 255.0))
        .preferredColorScheme(.dark)
        .onChange(of: selectedTab) { oldValue, newValue in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            guard newValue == .scan else { return }
            DispatchQueue.main.async {
                selectedTab = oldValue == .scan ? .home : oldValue
                isScanning = true
            }
        }
        .environment(\.openScanner) { isScanning = true }
        // In-app notifications: banner for new arrivals, feed on demand.
        .overlay(alignment: .top) {
            if let banner = notifications.banner {
                InAppNotificationBanner(
                    notification: banner,
                    onTap: { notifications.open(from: banner) },
                    onDismiss: { notifications.dismissBanner() }
                )
                .padding(.top, 4)
                .zIndex(10)
            }
        }
        .sheet(isPresented: $notifications.isPresented) {
            NotificationsSheet()
        }
        // Push notifications: the permission prompt lives on the onboarding
        // notifications step; here we only re-register (tokens can change),
        // and open the feed when a push is tapped.
        .task {
            await PushNotificationManager.shared.requestAuthorizationAndRegister(prompt: false)
        }
        // Waits for the splash on a cold launch from a push, so the sheet
        // doesn't open over the splash video.
        .onChange(of: PushNotificationManager.shared.pendingOpenNotifications && !isSplashShowing, initial: true) { _, open in
            guard open else { return }
            PushNotificationManager.shared.pendingOpenNotifications = false
            selectedTab = .home
            notifications.open()
            Task { await notifications.refresh() }
        }
        .environment(eventsVM)
        .qrScanner(isScanning: $isScanning) { code in
            if let payload = SuperDexQRPayload.decode(from: code) {
                scannedPayload = RootScannedPayload(username: payload.username)
            } else {
                unrecognizedCode = RootScannedQRCode(value: code)
            }
        }
        // New/Edit group sheets live at the root so Home and Deck share them.
        .sheet(isPresented: $viewModel.showingNewGroupSheet) {
            NewGroupView { name, description, date, location, link, wallpaperData, members in
                viewModel.createGroup(
                    name: name,
                    description: description,
                    eventDate: date,
                    location: location,
                    link: link,
                    wallpaperData: wallpaperData,
                    members: members
                )
            }
        }
        .sheet(item: $viewModel.groupBeingEdited) { group in
            NewGroupView(existingGroup: group) { name, description, date, location, link, wallpaperData, _ in
                viewModel.updateGroup(
                    id: group.id,
                    name: name,
                    description: description,
                    eventDate: date,
                    location: location,
                    link: link,
                    wallpaperData: wallpaperData
                )
            }
        }
        .sheet(item: $scannedPayload) { wrapper in
            ScannedProfileView(scannedUsername: wrapper.username)
        }
        .sheet(item: $unrecognizedCode) { result in
            RootScannedCodeSheet(code: result.value)
                .presentationDetents([.medium])
        }
    }
}

extension EnvironmentValues {
    /// Opens the app-wide QR scanner owned by ContentView (same as the Scan tab).
    @Entry var openScanner: () -> Void = {}
    /// True while the launch splash video is still on screen.
    @Entry var isSplashShowing: Bool = false
}

private struct RootScannedQRCode: Identifiable {
    let id = UUID()
    let value: String
}

private struct RootScannedPayload: Identifiable {
    let id = UUID()
    let username: String
}

private struct RootScannedCodeSheet: View {
    let code: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(code)
                    .font(.gilroy(.regular, size: 14))
                    .monospaced()
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Scanned Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(HomeViewModel())
        .environment(NotificationsViewModel())
        .preferredColorScheme(.dark)
}
