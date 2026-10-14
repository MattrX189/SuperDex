//
//  ReportContentView.swift
//  SuperDex
//
//  Lets a user flag another member's profile. Writes a row to `content_reports`
//  for the developer to review (App Store Review Guideline 1.2).
//

import SwiftUI
import Auth

struct ReportContentView: View {
    let reportedUserId: UUID
    let reportedName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM

    @State private var selectedReason: ReportReason = .spam
    @State private var details: String = ""
    @State private var isSubmitting = false
    @State private var toastMessage: String?

    @FocusState private var detailsFocused: Bool

    private let accent = Color(red: 0.294, green: 0.271, blue: 0.875)
    private let service = ModerationService()

    private var canSubmit: Bool { !isSubmitting }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        heroSection.padding(.top, 8)

                        formSection(title: "REASON", required: true) {
                            reasonPicker
                        }

                        formSection(title: "DETAILS", required: false) {
                            detailsField
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)

                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        toastView(toast).padding(.bottom, 28)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Report Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.75))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { Task { await submit() } }
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(canSubmit ? .white : .white.opacity(0.3))
                        .disabled(!canSubmit)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)
            RadialGradient(colors: [accent.opacity(0.30), .clear],
                           center: UnitPoint(x: 0.0, y: 0.0),
                           startRadius: 0, endRadius: 420)
            RadialGradient(colors: [accent.opacity(0.18), .clear],
                           center: UnitPoint(x: 1.0, y: 0.2),
                           startRadius: 0, endRadius: 360)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(accent.opacity(0.18))
                Image(systemName: "flag.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 56, height: 56)

            Text("Report \(reportedName)")
                .font(.gilroy(.bold, size: 17))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Tell us what's wrong. Our team reviews reports within 24 hours.")
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Reason picker

    private var reasonPicker: some View {
        VStack(spacing: 8) {
            ForEach(ReportReason.selectable) { reason in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedReason = reason
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedReason == reason ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selectedReason == reason ? accent : .white.opacity(0.4))

                        Text(reason.label)
                            .font(.gilroy(.semiBold, size: 15))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selectedReason == reason ? accent.opacity(0.7) : .white.opacity(0.10), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var detailsField: some View {
        TextField("",
                  text: $details,
                  prompt: Text("Add any details that help us review this (optional)")
                    .font(.gilroy(.regular, size: 15))
                    .foregroundColor(.white.opacity(0.35)),
                  axis: .vertical)
            .font(.gilroy(.regular, size: 15))
            .foregroundStyle(.white)
            .tint(accent)
            .focused($detailsFocused)
            .lineLimit(4...10)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(detailsFocused ? accent.opacity(0.7) : .white.opacity(0.10), lineWidth: 1)
                    )
            )
    }

    // MARK: - Section helper

    private func formSection<Content: View>(title: String, required: Bool,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.gilroy(.semiBold, size: 11))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.55))
                if required {
                    Text("•  REQUIRED")
                        .font(.gilroy(.semiBold, size: 10))
                        .tracking(1.2)
                        .foregroundStyle(accent.opacity(0.95))
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            content()
        }
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

    // MARK: - Submit

    private func submit() async {
        guard let userId = authVM.currentUser?.id else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await service.submitReport(
                reporterId: userId,
                reportedUserId: reportedUserId,
                reason: selectedReason,
                details: details
            )
            await showToast("Report sent. Thanks for keeping SuperDex safe.")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        } catch {
            await showToast("Couldn't send report. Please try again.")
        }
    }

    @MainActor
    private func showToast(_ message: String) async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toastMessage = message }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        withAnimation(.easeInOut(duration: 0.2)) { toastMessage = nil }
    }
}
