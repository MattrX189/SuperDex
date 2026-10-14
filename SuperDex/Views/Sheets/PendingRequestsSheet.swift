//
//  PendingRequestsSheet.swift
//  SuperDex
//
//  Shows incoming connect requests for a premium user.
//  Presented from the bell button in DiscoverView's header.
//

import SwiftUI

struct PendingRequestsSheet: View {
    @Environment(ContactRequestViewModel.self) private var requestVM
    @Environment(ContactsViewModel.self) private var contactsVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerText
                        .padding(.horizontal, 20)
                        .padding(.top, 28)

                    if requestVM.isLoading && requestVM.pendingRequests.isEmpty {
                        loadingState.padding(.top, 80)
                    } else if requestVM.pendingRequests.isEmpty {
                        emptyState.padding(.top, 80)
                    } else {
                        requestList
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
            await requestVM.refresh()
        }
    }

    // MARK: - Header

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connect Requests")
                .font(.gilroy(.bold, size: 34))
                .foregroundStyle(.white)

            Text(subtitleText)
                .font(.gilroy(.medium, size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var subtitleText: String {
        let count = requestVM.pendingCount
        switch count {
        case 0:  return "No pending requests right now."
        case 1:  return "1 person wants to connect with you."
        default: return "\(count) people want to connect with you."
        }
    }

    // MARK: - List

    private var requestList: some View {
        LazyVStack(spacing: 12) {
            ForEach(requestVM.pendingRequests) { request in
                RequestRow(request: request) { accept in
                    await requestVM.respond(to: request.id, accept: accept)
                    if accept {
                        await contactsVM.refresh()
                    }
                }
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white.opacity(0.7))
            Text("Loading requests…")
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.clock")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.35))

            Text("No requests yet")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))

            Text("When someone wants to connect with you, they'll appear here.")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - Request Row

private struct RequestRow: View {
    let request: ContactRequest
    let onRespond: (Bool) async -> Void

    @State private var isResponding = false

    var body: some View {
        HStack(spacing: 14) {
            Image(request.avatar)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.white.opacity(0.06)))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(request.fullName)
                    .font(.gilroy(.bold, size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if !request.subtitle.isEmpty {
                    Text(request.subtitle)
                        .font(.gilroy(.medium, size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Text(request.relativeTime)
                    .font(.gilroy(.semiBold, size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isResponding {
                ProgressView()
                    .tint(.white.opacity(0.7))
                    .frame(width: 76)
            } else {
                HStack(spacing: 8) {
                    // Reject
                    Button {
                        respond(accept: false)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)

                    // Accept
                    Button {
                        respond(accept: true)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
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

    private func respond(accept: Bool) {
        Task {
            isResponding = true
            await onRespond(accept)
            isResponding = false
        }
    }
}

#Preview {
    PendingRequestsSheet()
        .environment(ContactRequestViewModel())
        .environment(ContactsViewModel())
        .preferredColorScheme(.dark)
}
