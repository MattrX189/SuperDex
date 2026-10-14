//
//  ReportBugView.swift
//  SuperDex
//

import SwiftUI
import Supabase

struct ReportBugView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM

    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var isSubmitting = false
    @State private var toastMessage: String?

    @FocusState private var focusedField: Field?
    private enum Field { case title, description }

    private let accent = Color(red: 0.294, green: 0.271, blue: 0.875)
    private let service = FeedbackService()

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }
    private var trimmedDescription: String { descriptionText.trimmingCharacters(in: .whitespaces) }
    private var canSubmit: Bool { !trimmedTitle.isEmpty && !trimmedDescription.isEmpty && !isSubmitting }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        heroSection.padding(.top, 8)

                        formSection(title: "TITLE", required: true) {
                            titleField
                        }

                        formSection(title: "DESCRIPTION", required: true) {
                            descriptionField
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
            .navigationTitle("Report a Bug")
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
                Image(systemName: "ant.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 56, height: 56)

            Text("Found something off?")
                .font(.gilroy(.bold, size: 17))
                .foregroundStyle(.white)
            Text("Tell us what happened — we'll take a look.")
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Fields

    private var titleField: some View {
        HStack(spacing: 12) {
            Image(systemName: "textformat")
                .font(.gilroy(.semiBold, size: 15))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 22)

            TextField("",
                      text: $title,
                      prompt: Text("e.g. App crashes when opening QR")
                        .font(.gilroy(.regular, size: 15))
                        .foregroundColor(.white.opacity(0.35)))
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white)
                .tint(accent)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .description }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(fieldBackground(focused: focusedField == .title))
    }

    private var descriptionField: some View {
        TextField("",
                  text: $descriptionText,
                  prompt: Text("Steps to reproduce, what you expected, what happened…")
                    .font(.gilroy(.regular, size: 15))
                    .foregroundColor(.white.opacity(0.35)),
                  axis: .vertical)
            .font(.gilroy(.regular, size: 15))
            .foregroundStyle(.white)
            .tint(accent)
            .focused($focusedField, equals: .description)
            .lineLimit(5...12)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background(fieldBackground(focused: focusedField == .description))
    }

    // MARK: - Section helper

    private func formSection<Content: View>(title: String, required: Bool = false,
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

    private func fieldBackground(focused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(focused ? accent.opacity(0.7) : .white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(.easeInOut(duration: 0.2), value: focused)
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
            try await service.submitBugReport(
                userId: userId,
                title: trimmedTitle,
                description: trimmedDescription
            )
            await showToast("Bug report sent. Thanks!")
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            await showToast("Couldn't send. Please try again.")
        }
    }

    @MainActor
    private func showToast(_ message: String) async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toastMessage = message }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        withAnimation(.easeInOut(duration: 0.2)) { toastMessage = nil }
    }
}
