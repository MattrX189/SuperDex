//
//  SuperDexApp.swift
//  SuperDex
//
//  Created by Gaurang Pant on 4/26/26.
//

import SwiftUI
import Auth
import RevenueCat
import AVFoundation

@main
struct CategoryCardsApp: App {
    /// APNs callbacks → PushNotificationManager.
    @UIApplicationDelegateAdaptor(SuperDexAppDelegate.self) private var appDelegate
    @State private var splashFinished = false
    #if DEBUG
    @State private var debugOnboardingFinished = false
    #endif
    @State private var contentOpacity: Double = 0
    @State private var auth = AuthViewModel()
    @State private var userProfile = UserProfileViewModel()
    @State private var home = HomeViewModel()
    @State private var contacts = ContactsViewModel()
    @State private var discover = DiscoverViewModel()
    @State private var subscription = SubscriptionManager()
    @State private var contactRequests = ContactRequestViewModel()
    @State private var deviceContacts = DeviceContactsViewModel()
    @State private var notifications = NotificationsViewModel()
    @State private var blockStore = BlockStore()

    init() {
        SubscriptionManager.configure()
        // The app has no audio of its own (splash video is muted). `.ambient`
        // + `.mixWithOthers` keeps the user's music playing instead of the
        // default `.soloAmbient`, which pauses other apps' audio on AVPlayer start.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                rootContent
                    .opacity(contentOpacity)
                    .environment(auth)
                    .environment(userProfile)
                    .environment(home)
                    .environment(contacts)
                    .environment(discover)
                    .environment(subscription)
                    .environment(contactRequests)
                    .environment(deviceContacts)
                    .environment(notifications)
                    .environment(blockStore)
                    .environment(\.isSplashShowing, !splashFinished)

                if !splashFinished {
                    SplashVidView(isFinished: $splashFinished)
                        .transition(.opacity)
                }
            }
            .task(id: auth.currentUser?.id) {
                if let user = auth.currentUser {
                    let isFreshSignIn = auth.isFreshSignIn
                    auth.isFreshSignIn = false
                    await userProfile.load(for: user, isFreshSignIn: isFreshSignIn)
                    await home.load(for: user)
                    await contacts.load(for: user)
                    await discover.load(for: user)
                    await contactRequests.load(for: user)
                    deviceContacts.configure(userId: user.id)
                    await notifications.load(for: user)
                    PushNotificationManager.shared.setUser(user.id)
                    await subscription.identify(userID: user.id.uuidString)
                    await subscription.refresh()
                    await userProfile.applyPremiumStatus(subscription.isPro)
                } else if case .signedOut = auth.state {
                    userProfile.clearOnSignOut()
                    home.clearOnSignOut()
                    contacts.clearOnSignOut()
                    discover.clearOnSignOut()
                    contactRequests.clearOnSignOut()
                    deviceContacts.clearOnSignOut()
                    notifications.clearOnSignOut()
                    await subscription.logOut()
                }
            }
            .onChange(of: subscription.isPro) { _, isPro in
                guard subscription.hasSynced else { return }
                Task { await userProfile.applyPremiumStatus(isPro) }
            }
            .onChange(of: splashFinished) { _, finished in
                guard finished else { return }
                withAnimation(.easeIn(duration: 1.2)) {
                    contentOpacity = 1
                }
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if DebugFlags.onboardingPreview {
            debugOnboardingPreview
        } else {
            appContent
        }
        #else
        appContent
        #endif
    }

    #if DEBUG
    /// Theme picker → card-ready slingshot → Home's My Card landing,
    /// without signing in or saving anything (see DebugFlags).
    @ViewBuilder
    private var debugOnboardingPreview: some View {
        if debugOnboardingFinished {
            ContentView()
        } else {
            OnboardingView(startStep: .theme) {
                withAnimation(.easeOut(duration: 0.3)) { debugOnboardingFinished = true }
            }
        }
    }
    #endif

    @ViewBuilder
    private var appContent: some View {
        switch auth.state {
        case .loading:
            Color.black
        case .signedOut:
            GetStartedCarouselView()
        case .signedIn:
            if userProfile.needsOnboarding {
                OnboardingView()
            } else if userProfile.needsThemeRefresh {
                // Returning account: theme picker, then the card launch.
                OnboardingView(startStep: .theme, isReturning: true)
            } else {
                ContentView()
            }
        }
    }
}
