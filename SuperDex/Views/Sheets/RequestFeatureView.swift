//
//  RequestFeatureView.swift
//  SuperDex
//

import SwiftUI
import Supabase

struct RequestFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authVM

    @State private var requests: [FeatureRequest] = []
    @State private var isLoading = false
    @State private var showComposer = false
    @State private var toastMessage: String?

    private let accent = Color(red: 0.294, green: 0.271, blue: 0.875)
    private let service = FeedbackService()

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        heroSection.padding(.top, 8).padding(.bottom, 4)

                        if isLoading && requests.isEmpty {
                            loadingState
                        } else if requests.isEmpty {
                            emptyState
                        } else {
                            ForEach(requests) { request in
                                requestCard(request)
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .refreshable { await load() }

                VStack {
                    Spacer()
                    newRequestButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }

                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        toastView(toast).padding(.bottom, 96)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Feature Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        .task { await load() }
        .sheet(isPresented: $showComposer) {
            FeatureComposerView { title, description in
                await submitNew(title: title, description: description)
            }
            .environment(authVM)
        }
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
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 56, height: 56)

            Text("Shape what's next")
                .font(.gilroy(.bold, size: 17))
                .foregroundStyle(.white)
            Text("Suggest features or upvote ideas you'd love to see.")
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Request card

    private func requestCard(_ request: FeatureRequest) -> some View {
        HStack(alignment: .top, spacing: 14) {
            upvotePill(request)

            VStack(alignment: .leading, spacing: 6) {
                Text(request.title)
                    .font(.gilroy(.bold, size: 15))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                if !request.description.isEmpty {
                    Text(request.description)
                        .font(.gilroy(.regular, size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                }

                if request.isOwn {
                    Text("YOUR REQUEST")
                        .font(.gilroy(.semiBold, size: 9))
                        .tracking(1.2)
                        .foregroundStyle(accent.opacity(0.85))
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func upvotePill(_ request: FeatureRequest) -> some View {
        Button { Task { await toggleUpvote(request) } } label: {
            VStack(spacing: 2) {
                Image(systemName: request.hasUpvoted ? "chevron.up.circle.fill" : "chevron.up")
                    .font(.system(size: request.hasUpvoted ? 18 : 14, weight: .bold))
                Text("\(request.upvoteCount)")
                    .font(.gilroy(.bold, size: 13))
            }
            .foregroundStyle(request.hasUpvoted ? .white : .white.opacity(0.85))
            .frame(width: 44, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(request.hasUpvoted ? AnyShapeStyle(accent) : AnyShapeStyle(Color.white.opacity(0.06)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(request.hasUpvoted ? accent.opacity(0.6) : .white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: request.hasUpvoted ? accent.opacity(0.35) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - States

    private var loadingState: some View {
        ProgressView().tint(.white.opacity(0.7)).padding(.top, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No feature requests yet")
                .font(.gilroy(.bold, size: 15))
                .foregroundStyle(.white.opacity(0.85))
            Text("Be the first to suggest one.")
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 32)
    }

    // MARK: - New button

    private var newRequestButton: some View {
        Button { showComposer = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                Text("New Request")
                    .font(.gilroy(.bold, size: 15))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [accent, accent.opacity(0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.40), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
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

    // MARK: - Actions

    private func load() async {
        guard let userId = authVM.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            requests = try await service.fetchFeatureRequests(currentUserId: userId)
        } catch {
            await showToast("Couldn't load requests.")
        }
    }

    private func toggleUpvote(_ request: FeatureRequest) async {
        guard let userId = authVM.currentUser?.id else { return }
        guard let idx = requests.firstIndex(where: { $0.id == request.id }) else { return }

        let wasUpvoted = requests[idx].hasUpvoted
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            requests[idx].hasUpvoted.toggle()
            requests[idx].upvoteCount += wasUpvoted ? -1 : 1
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        do {
            if wasUpvoted {
                try await service.removeUpvote(featureRequestId: request.id, userId: userId)
            } else {
                try await service.upvote(featureRequestId: request.id, userId: userId)
            }
        } catch {
            withAnimation {
                requests[idx].hasUpvoted = wasUpvoted
                requests[idx].upvoteCount += wasUpvoted ? 1 : -1
            }
            await showToast("Couldn't update vote.")
        }
    }

    private func submitNew(title: String, description: String) async {
        guard let userId = authVM.currentUser?.id else { return }
        do {
            _ = try await service.submitFeatureRequest(userId: userId, title: title, description: description)
            await load()
            await showToast("Request submitted!")
        } catch {
            await showToast("Couldn't submit. Try again.")
        }
    }

    @MainActor
    private func showToast(_ message: String) async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toastMessage = message }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        withAnimation(.easeInOut(duration: 0.2)) { toastMessage = nil }
    }
}

// MARK: - Composer

private struct FeatureComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?
    private enum Field { case title, description }

    private let accent = Color(red: 0.294, green: 0.271, blue: 0.875)
    let onSubmit: (_ title: String, _ description: String) async -> Void

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }
    private var canSubmit: Bool { !trimmedTitle.isEmpty && !isSubmitting }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        section(title: "TITLE", required: true) {
                            HStack(spacing: 12) {
                                Image(systemName: "textformat")
                                    .font(.gilroy(.semiBold, size: 15))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .frame(width: 22)
                                TextField("",
                                          text: $title,
                                          prompt: Text("e.g. Dark mode for QR codes")
                                            .font(.gilroy(.regular, size: 15))
                                            .foregroundColor(.white.opacity(0.35)))
                                    .font(.gilroy(.semiBold, size: 16))
                                    .foregroundStyle(.white)
                                    .tint(accent)
                                    .focused($focusedField, equals: .title)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .description }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(fieldBackground(focused: focusedField == .title))
                        }

                        section(title: "DETAILS") {
                            TextField("",
                                      text: $descriptionText,
                                      prompt: Text("Why this feature would help… (optional)")
                                        .font(.gilroy(.regular, size: 15))
                                        .foregroundColor(.white.opacity(0.35)),
                                      axis: .vertical)
                                .font(.gilroy(.regular, size: 15))
                                .foregroundStyle(.white)
                                .tint(accent)
                                .focused($focusedField, equals: .description)
                                .lineLimit(4...10)
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                .contentShape(Rectangle())
                                .background(fieldBackground(focused: focusedField == .description))
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.75))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            isSubmitting = true
                            await onSubmit(trimmedTitle, descriptionText.trimmingCharacters(in: .whitespaces))
                            isSubmitting = false
                            dismiss()
                        }
                    }
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(canSubmit ? .white : .white.opacity(0.3))
                    .disabled(!canSubmit)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)
            RadialGradient(colors: [accent.opacity(0.30), .clear],
                           center: UnitPoint(x: 0.0, y: 0.0),
                           startRadius: 0, endRadius: 420)
        }
    }

    private func section<Content: View>(title: String, required: Bool = false,
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
}
