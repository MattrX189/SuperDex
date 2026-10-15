//
//  OnboardingNotificationsStep.swift
//  SuperDex
//
//  "Allow notifications" page, shown before the theme step — after the
//  profile form for new accounts, right after sign-in for returning ones.
//  The system prompt appears on this page; once it's answered we move on.
//  Skipped when the user has already answered the prompt on this device.
//

import SwiftUI
import UserNotifications

struct OnboardingNotificationsStep: View {
    let accent: Color
    let onDone: () -> Void

    /// Hidden until we know the prompt hasn't been answered already.
    @State private var isVisible = false
    @State private var isRequesting = false
    @State private var isFinished = false
    @State private var bellRings = false

    var body: some View {
        // iOS always centers its permission alert, so the page keeps the
        // middle of the screen empty for it: title up top, reasons and
        // buttons below where the alert sits.
        GeometryReader { geo in
            ViewThatFits(in: .vertical) {
                layout(alertGap: geo.size.height * 0.34, showsReasons: true)
                layout(alertGap: geo.size.height * 0.34, showsReasons: false)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .opacity(isVisible ? 1 : 0)
        .task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            guard status == .notDetermined else {
                // Already answered (e.g. signing back in on the same phone):
                // just re-register and carry on to the theme step.
                await PushNotificationManager.shared.requestAuthorizationAndRegister()
                finish()
                return
            }
            withAnimation(.easeOut(duration: 0.35)) { isVisible = true }
            // Let the page land, then bring up the system prompt on it.
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await requestPermission()
        }
    }

    private func layout(alertGap: CGFloat, showsReasons: Bool) -> some View {
        VStack(spacing: 0) {
            hero
                .padding(.top, 16)
                .padding(.bottom, 22)

            VStack(spacing: 10) {
                Text("Stay updated")
                    .font(.gilroy(.bold, size: 30))
                    .foregroundStyle(.white)

                Text("Allow notifications so you know the moment someone connects with you.")
                    .font(.gilroy(.regular, size: 16))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)

            // Room for the system alert.
            Spacer(minLength: alertGap)

            if showsReasons {
                VStack(alignment: .leading, spacing: 12) {
                    reason(icon: "person.badge.plus", text: "New connection requests")
                    reason(icon: "checkmark.circle", text: "When people accept your request")
                    reason(icon: "rectangle.portrait.on.rectangle.portrait", text: "When someone shares their card")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .padding(.bottom, 16)
            }

            VStack(spacing: 6) {
                Button {
                    Task { await requestPermission() }
                } label: {
                    Text("Allow Notifications")
                        .font(.gilroy(.semiBold, size: 17))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background { Capsule().fill(.white) }
                }
                .glassEffect(.regular.interactive(), in: .capsule)

                Button("Not now", action: finish)
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 10)
            }
            .disabled(isRequesting)
        }
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.22))
                .frame(width: 96, height: 96)
            Circle()
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                .frame(width: 96, height: 96)
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 38, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.red, .white)
                .symbolEffect(.wiggle, value: bellRings)
        }
        .onAppear { bellRings.toggle() }
    }

    private func reason(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24)
            Text(text)
                .font(.gilroy(.medium, size: 15))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    /// Shows the system prompt (once), then continues whatever the answer.
    private func requestPermission() async {
        guard !isRequesting, !isFinished else { return }
        isRequesting = true
        await PushNotificationManager.shared.requestAuthorizationAndRegister()
        isRequesting = false
        finish()
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        onDone()
    }
}
