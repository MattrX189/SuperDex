//
//  GigApplicantsSheet.swift
//  SuperDex
//
//  The poster's applicant list, in the same style as
//  EventAttendeesSheet: masked cards (name, role, company, bio)
//  plus each applicant's pitch, with the standard Connect pill —
//  connecting is how the poster "accepts" someone, and the accepted
//  connection lands in Contacts.
//

import SwiftUI

struct GigApplicantsSheet: View {
    let post: GigPost
    let viewModel: GigsViewModel

    @Environment(ContactRequestViewModel.self) private var requestVM
    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(\.dismiss) private var dismiss

    @State private var applicants: [GigApplicant] = []
    @State private var isLoading = true

    private func connectState(for applicant: GigApplicant) -> DiscoverConnectState {
        if contactsVM.contactExists(contactUserId: applicant.id) { return .connected }
        switch requestVM.sentStatuses[applicant.id] {
        case .pending:          return .pending
        case .accepted:         return .connected
        case .rejected, .none:  return .connect
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerText
                        .padding(.horizontal, 20)
                        .padding(.top, 28)

                    if isLoading && applicants.isEmpty {
                        loadingState.padding(.top, 80)
                    } else if applicants.isEmpty {
                        emptyState.padding(.top, 80)
                    } else {
                        applicantList
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 24)
                    }
                }
            }
            .background(AppBackground())

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
        .task {
            isLoading = true
            if let fetched = await viewModel.fetchApplicants(for: post) {
                applicants = fetched
            }
            isLoading = false
            await requestVM.refresh()
        }
    }

    // MARK: - Header

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Applicants")
                .font(.gilroy(.bold, size: 34))
                .foregroundStyle(.white)

            Text(subtitleText)
                .font(.gilroy(.medium, size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.trailing, 44)
    }

    private var subtitleText: String {
        switch applicants.count {
        case 0:  return "People who apply to \"\(post.title)\" show up here."
        case 1:  return "1 person applied to \"\(post.title)\". Connect to start the conversation."
        default: return "\(applicants.count) people applied to \"\(post.title)\". Connect to start the conversation."
        }
    }

    // MARK: - List

    private var applicantList: some View {
        LazyVStack(spacing: 12) {
            ForEach(applicants) { applicant in
                applicantRow(applicant)
            }
        }
    }

    private func applicantRow(_ applicant: GigApplicant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                avatarView(applicant)

                VStack(alignment: .leading, spacing: 3) {
                    Text(applicant.fullName)
                        .font(.gilroy(.bold, size: 16))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !applicant.subtitle.isEmpty {
                        Text(applicant.subtitle)
                            .font(.gilroy(.medium, size: 13))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }

                    if !applicant.bio.isEmpty {
                        Text(applicant.bio)
                            .font(.gilroy(.regular, size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 8)

                DiscoverConnectPill(
                    state: connectState(for: applicant),
                    action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await requestVM.sendRequest(to: applicant.id) }
                    },
                    onWithdraw: {
                        Task { await requestVM.withdrawRequest(to: applicant.id) }
                    }
                )
            }

            if !applicant.message.isEmpty {
                Text("\u{201C}\(applicant.message)\u{201D}")
                    .font(.gilroy(.regular, size: 13))
                    .italic()
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func avatarView(_ applicant: GigApplicant) -> some View {
        if applicant.avatar.isEmpty {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 50, height: 50)
        } else {
            Image(applicant.avatar)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.white.opacity(0.06)))
                .clipShape(Circle())
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white.opacity(0.7))
            Text("Loading applicants…")
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.35))

            Text("No applicants yet")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))

            Text("When someone applies to your requirement, they'll appear here.")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}
