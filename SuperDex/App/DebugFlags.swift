//
//  DebugFlags.swift
//  SuperDex
//
//  Developer switches. Compiled into DEBUG builds only — release builds
//  can never see them.
//

#if DEBUG
enum DebugFlags {
    /// Skip sign-in and open straight on onboarding's theme picker, then
    /// the card-ready slingshot and Home's My Card landing. Nothing is
    /// saved to the account. Relaunch the app to play it again.
    /// Set back to `false` to use the app normally.
    static let onboardingPreview = false
}
#endif
