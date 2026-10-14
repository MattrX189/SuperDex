//
//  AuthViewModel.swift
//  SuperDex
//

import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

@MainActor
@Observable
final class AuthViewModel {
    enum State {
        case loading
        case signedOut
        case signedIn(User)
    }

    var state: State = .loading
    var isWorking = false
    var errorMessage: String?
    /// True when the current session came from signing in just now, rather
    /// than being restored on launch. Read once by the profile load.
    var isFreshSignIn = false

    var currentUser: User? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    private let client = SupabaseManager.client

    init() {
        Task { await observeAuthChanges() }
    }

    private func observeAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                if event == .signedIn { isFreshSignIn = true }
                if let user = session?.user {
                    state = .signedIn(user)
                } else {
                    state = .signedOut
                }
            case .signedOut:
                state = .signedOut
            default:
                break
            }
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            if response.session == nil {
                errorMessage = "Check your email to confirm your account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendPhoneOTP(phone: String) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.signInWithOTP(phone: phone)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyPhoneOTP(phone: String, code: String) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.verifyOTP(phone: phone, token: code, type: .sms)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendEmailOTP(email: String) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.signInWithOTP(email: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyEmailOTP(email: String, code: String) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.verifyOTP(email: email, token: code, type: .email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign in with Apple

    /// Raw nonce for the in-flight Apple request. Apple gets its SHA-256 hash;
    /// Supabase gets the raw value and checks they match.
    private var appleNonce: String?

    /// Name Apple shared on this sign-in. Apple only sends it the first time,
    /// and before the metadata write lands, so keep it for onboarding.
    private(set) var appleName: (first: String, last: String)?

    /// Best first/last name for prefilling onboarding: this session's Apple
    /// name, else what was saved to user metadata on an earlier Apple sign-in.
    var suggestedName: (first: String, last: String)? {
        if let appleName { return appleName }
        guard let metadata = currentUser?.userMetadata else { return nil }
        let first = metadata["given_name"]?.stringValue ?? ""
        let last = metadata["family_name"]?.stringValue ?? ""
        if !first.isEmpty || !last.isEmpty { return (first, last) }
        let parts = (metadata["full_name"]?.stringValue ?? "").split(separator: " ", maxSplits: 1)
        guard let head = parts.first else { return nil }
        return (String(head), parts.count > 1 ? String(parts[1]) : "")
    }

    /// Configure the `SignInWithAppleButton` request.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the `SignInWithAppleButton` result by exchanging Apple's ID token
    /// for a Supabase session.
    func signInWithApple(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        let nonce = appleNonce
        appleNonce = nil

        let authorization: ASAuthorization
        switch result {
        case .success(let value):
            authorization = value
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription
            return
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce else {
            errorMessage = "Couldn't sign in with Apple. Please try again."
            return
        }

        if let name = credential.fullName {
            let first = name.givenName ?? ""
            let last = name.familyName ?? ""
            if !first.isEmpty || !last.isEmpty { appleName = (first, last) }
        }

        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
            )
            // Apple only shares the name on the very first sign-in, and it isn't
            // in the ID token, so save it to user metadata while we have it.
            if let name = credential.fullName {
                let given = name.givenName ?? ""
                let family = name.familyName ?? ""
                let full = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
                if !full.isEmpty {
                    _ = try? await client.auth.update(user: UserAttributes(data: [
                        "full_name": .string(full),
                        "given_name": .string(given),
                        "family_name": .string(family)
                    ]))
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func signOut() {
        errorMessage = nil
        appleName = nil
        isFreshSignIn = false
        // Flip state synchronously so the root view swaps to the signed-out
        // screen the instant the user taps — no spinner, no waiting on a
        // network round-trip to Supabase's revoke endpoint.
        state = .signedOut

        // Clean up in the background. The user never waits for this.
        //  - `.global` clears the local session AND revokes the refresh token
        //    server-side (the right thing to do).
        //  - If `.global` fails (offline / expired token / 401), fall back to
        //    `.local` so the keychain is always cleared and the session can't
        //    restore on next launch.
        Task.detached {
            // Stop pushes to this phone first — that call needs the session.
            await PushNotificationManager.shared.unregisterForSignOut()
            do {
                try await SupabaseManager.client.auth.signOut(scope: .global)
            } catch {
                try? await SupabaseManager.client.auth.signOut(scope: .local)
            }
        }
    }

    /// Permanently deletes the signed-in user's data and auth record, then clears
    /// the local session. Relies on the `delete_account` SECURITY DEFINER function
    /// in Supabase, since the anon key cannot remove an `auth.users` row directly.
    @discardableResult
    func deleteAccount() async -> Bool {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        // Storage objects must be cleared via the Storage API (Postgres blocks
        // direct deletes from storage.objects). Best-effort, while still signed in.
        if let uid = currentUser?.id {
            try? await PortfolioStorageService().deleteAll(userId: uid)
        }

        do {
            try await client.rpc("delete_account").execute()
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        // Account is gone server-side; clear the now-invalid local session.
        try? await client.auth.signOut(scope: .local)
        return true
    }
}
