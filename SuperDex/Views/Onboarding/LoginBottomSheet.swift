//
//  LoginBottomSheet.swift
//  SuperDex
//

import AuthenticationServices
import SwiftUI

struct LoginBottomSheet: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var showEmailLogin = false

    @State private var email = ""
    @State private var otpCode = ""
    @State private var otpSent = false
    @State private var successMessage: String?

    private let accent = Color(red: 0.45, green: 0.40, blue: 0.95)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    logoRow
                        .padding(.top, 40)

                    titleSection

                    if showEmailLogin {
                        emailLoginFields
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        authButtons
                            .transition(.opacity)
                    }

                    Text("By continuing, you agree to SuperDex's [Terms of Use](https://www.superdex.in/terms) and [Privacy Policy](https://www.superdex.in/privacy).")
                        .font(.gilroy(.regular, size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                        .tint(accent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)

            RadialGradient(
                colors: [accent.opacity(0.30), .clear],
                center: UnitPoint(x: 0.0, y: 0.0),
                startRadius: 0,
                endRadius: 420
            )

            RadialGradient(
                colors: [accent.opacity(0.18), .clear],
                center: UnitPoint(x: 1.0, y: 0.2),
                startRadius: 0,
                endRadius: 360
            )
        }
    }

    // MARK: - Logo + Close

    private var logoRow: some View {
        HStack {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 152, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Get Started")
                .font(.gilroy(.bold, size: 28))
                .foregroundStyle(.white)

            Text("Create your digital card, share it instantly, and keep all your connections in one place.")
                .font(.gilroy(.regular, size: 16))
                .foregroundStyle(.white.opacity(0.50))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Auth Buttons

    private var authButtons: some View {
        VStack(spacing: 14) {
            SignInWithAppleButton(.continue) { request in
                auth.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await auth.signInWithApple(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(auth.isWorking)
            .overlay {
                if auth.isWorking {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .overlay(ProgressView().tint(.black))
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showEmailLogin = true
                    resetOTPState()
                }
            } label: {
                Label("Continue with Email", systemImage: "envelope.fill")
                    .font(.gilroy(.semiBold, size: 17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            errorOrSuccessView
        }
    }

    // MARK: - Email OTP Flow

    private var emailLoginFields: some View {
        VStack(spacing: 14) {
            if !otpSent {
                HStack(spacing: 14) {
                    Image(systemName: "envelope")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 24)

                    ZStack(alignment: .leading) {
                        if email.isEmpty {
                            Text("you@example.com")
                                .font(.gilroy(.regular, size: 16))
                                .foregroundStyle(Color(white: 0.5))
                        }
                        TextField("", text: $email)
                            .font(.gilroy(.regular, size: 16))
                            .foregroundStyle(.white)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .tint(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(fieldBackground)

                actionButton(title: "Send OTP", enabled: !email.isEmpty && email.contains("@")) {
                    Task {
                        await auth.sendEmailOTP(email: email)
                        if auth.errorMessage == nil {
                            withAnimation(.easeInOut(duration: 0.25)) { otpSent = true }
                        }
                    }
                }
            } else {
                sentBanner(detail: email)

                otpField

                actionButton(title: "Verify & Continue", enabled: otpCode.count >= 6) {
                    Task { await auth.verifyEmailOTP(email: email, code: otpCode) }
                }

                resendButton {
                    Task { await auth.sendEmailOTP(email: email) }
                    successMessage = "Code resent!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { successMessage = nil }
                }
            }

            errorOrSuccessView

            backButton {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showEmailLogin = false
                    resetOTPState()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shared Components

    private var otpField: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 24)

            TextField(
                "",
                text: $otpCode,
                prompt: Text("Enter 6-digit code")
                    .font(.gilroy(.regular, size: 16))
                    .foregroundColor(.white.opacity(0.35))
            )
            .font(.gilroy(.semiBold, size: 20))
            .foregroundStyle(.white)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .tint(accent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(fieldBackground)
    }

    private func sentBanner(detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 14))
                .foregroundStyle(accent)

            Text("Code sent to **\(detail)**")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func actionButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                if auth.isWorking {
                    ProgressView().tint(.black)
                } else {
                    Text(title)
                        .font(.gilroy(.semiBold, size: 17))
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.black)
            .padding(.vertical, 17)
            .background(enabled && !auth.isWorking ? Color.white : Color.white.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!enabled || auth.isWorking)
    }

    private func resendButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Resend code")
                .font(.gilroy(.medium, size: 15))
                .foregroundStyle(accent)
        }
        .disabled(auth.isWorking)
    }

    @ViewBuilder
    private var errorOrSuccessView: some View {
        if let message = auth.errorMessage {
            Text(message)
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        } else if let success = successMessage {
            Text(success)
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Back to all options")
                .font(.gilroy(.medium, size: 15))
                .foregroundStyle(.white.opacity(0.50))
        }
        .padding(.top, 4)
    }

    // MARK: - Field Background

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
    }

    // MARK: - Helpers

    private func resetOTPState() {
        otpCode = ""
        otpSent = false
        successMessage = nil
        auth.errorMessage = nil
    }
}

#Preview {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            LoginBottomSheet()
                .environment(AuthViewModel())
        }
        .preferredColorScheme(.dark)
}
