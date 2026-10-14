//
//  GigComposerSheet.swift
//  SuperDex
//
//  "Post a requirement" form, also reused to edit an existing post
//  (pass `editingPost`). Text runs through ContentModeration before
//  submitting (Guideline 1.2 — filter objectionable content before
//  it reaches the feed).
//

import SwiftUI

/// Currencies offered when posting a requirement's budget.
enum GigCurrency: String, CaseIterable, Identifiable {
    case inr, usd, gbp

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .inr: return "₹"
        case .usd: return "$"
        case .gbp: return "£"
        }
    }

    var label: String {
        switch self {
        case .inr: return "₹ INR"
        case .usd: return "$ USD"
        case .gbp: return "£ GBP"
        }
    }
}

struct GigComposerSheet: View {
    let viewModel: GigsViewModel
    /// When set, the sheet edits this post instead of creating one.
    var editingPost: GigPost? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var descriptionText = ""
    @State private var category: ProfileCategory = .technologySoftware
    @State private var currency: GigCurrency = .inr
    @State private var budgetAmount = ""
    @State private var durationText = ""
    @State private var location = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didPrefill = false

    private var isEditing: Bool { editingPost != nil }

    private var submitButtonTitle: String {
        if isSubmitting { return isEditing ? "Saving…" : "Posting…" }
        return isEditing ? "Save Changes" : "Post Requirement"
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !budgetAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isSubmitting
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    field("What do you need?") {
                        styledTextField(
                            "e.g. UI/UX designer for a freelance gig",
                            text: $title
                        )
                    }

                    field("Details *") {
                        styledEditor($descriptionText)
                    }

                    field("Category") {
                        categoryPicker
                    }

                    field("Budget *") {
                        VStack(spacing: 10) {
                            currencySelector
                            styledTextField("e.g. 70,000", text: $budgetAmount)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }

                    HStack(spacing: 12) {
                        field("Duration") {
                            styledTextField("e.g. 1 month", text: $durationText)
                        }
                        field("Location") {
                            styledTextField("e.g. Remote", text: $location)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.gilroy(.medium, size: 13))
                            .foregroundStyle(.red.opacity(0.9))
                    }

                    postButton
                        .padding(.top, 4)

                    Text("Your post is visible to every SuperDex member for 30 days. Applicants share only their name, role, company and bio until you connect with them.")
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
            }
            .background(AppBackground())
            .scrollDismissesKeyboard(.interactively)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .contentShape(Circle())
                    .glassEffect(.clear.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, 24)
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: prefillIfEditing)
    }

    /// Loads the edited post's values into the fields once.
    private func prefillIfEditing() {
        guard let post = editingPost, !didPrefill else { return }
        didPrefill = true
        title = post.title
        descriptionText = post.descriptionText
        category = post.category ?? .technologySoftware
        durationText = post.durationText ?? ""
        location = post.location ?? ""

        // Split a stored budget like "₹70,000" back into currency +
        // amount; legacy free-text budgets fall into the amount field.
        if let stored = post.budgetText?.trimmingCharacters(in: .whitespaces), !stored.isEmpty {
            if let match = GigCurrency.allCases.first(where: { stored.hasPrefix($0.symbol) }) {
                currency = match
                budgetAmount = String(stored.dropFirst(match.symbol.count))
                    .trimmingCharacters(in: .whitespaces)
            } else {
                budgetAmount = stored
            }
        }
    }

    // MARK: - Submit

    private func submit() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAmount = budgetAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDuration = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)

        // Budget is mandatory; combine the chosen currency with the
        // amount, e.g. "₹70,000".
        let cleanBudget = "\(currency.symbol)\(cleanAmount)"

        if let term = [cleanTitle, cleanDescription, cleanAmount, cleanDuration, cleanLocation]
            .compactMap(ContentModeration.firstObjectionableTerm(in:))
            .first {
            errorMessage = "\"\(term)\" isn't allowed in a post. Please reword it."
            return
        }

        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                if let post = editingPost {
                    try await viewModel.updatePost(
                        postId: post.id,
                        title: cleanTitle,
                        description: cleanDescription,
                        category: category,
                        budgetText: cleanBudget.isEmpty ? nil : cleanBudget,
                        durationText: cleanDuration.isEmpty ? nil : cleanDuration,
                        location: cleanLocation.isEmpty ? nil : cleanLocation
                    )
                } else {
                    try await viewModel.createPost(
                        title: cleanTitle,
                        description: cleanDescription,
                        category: category,
                        budgetText: cleanBudget.isEmpty ? nil : cleanBudget,
                        durationText: cleanDuration.isEmpty ? nil : cleanDuration,
                        location: cleanLocation.isEmpty ? nil : cleanLocation
                    )
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                errorMessage = isEditing
                    ? "Couldn't save changes. Please try again."
                    : "Couldn't post right now. Please try again."
                isSubmitting = false
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isEditing ? "Edit Requirement" : "Post a Requirement")
                .font(.gilroy(.bold, size: 34))
                .foregroundStyle(.white)

            Text(isEditing
                ? "Update the details of your opportunity."
                : "Tell SuperDex members what you're looking for — anyone can apply.")
                .font(.gilroy(.medium, size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.trailing, 44)
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.gilroy(.semiBold, size: 13))
                .foregroundStyle(.white.opacity(0.55))
            content()
        }
    }

    private var currencySelector: some View {
        HStack(spacing: 8) {
            ForEach(GigCurrency.allCases) { option in
                let isSelected = currency == option
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        currency = option
                    }
                } label: {
                    Text(option.label)
                        .font(.gilroy(.semiBold, size: 14))
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            Capsule().fill(isSelected
                                           ? AnyShapeStyle(.white)
                                           : AnyShapeStyle(.white.opacity(0.06)))
                        )
                        .overlay(
                            Capsule().strokeBorder(isSelected ? .clear : .white.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func styledTextField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text(prompt)
                .font(.gilroy(.regular, size: 15))
                .foregroundColor(.white.opacity(0.35))
        )
        .font(.gilroy(.regular, size: 15))
        .foregroundStyle(.white)
        .tint(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func styledEditor(_ text: Binding<String>) -> some View {
        TextEditor(text: text)
            .font(.gilroy(.regular, size: 15))
            .foregroundStyle(.white)
            .tint(.white)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 120)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var categoryPicker: some View {
        Menu {
            ForEach(ProfileCategory.allCases) { option in
                Button {
                    category = option
                } label: {
                    Label(option.displayName, systemImage: option.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.indigo)

                Text(category.displayName)
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var postButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            submit()
        } label: {
            HStack(spacing: 10) {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: isEditing ? "checkmark" : "paperplane.fill")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(submitButtonTitle)
                    .font(.gilroy(.bold, size: 16))
                    .tracking(0.5)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [.indigo, .indigo.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .indigo.opacity(0.4), radius: 14, y: 7)
            .opacity(canSubmit ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }
}

#Preview {
    GigComposerSheet(viewModel: GigsViewModel())
        .preferredColorScheme(.dark)
}
