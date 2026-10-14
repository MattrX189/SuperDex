//
//  EditGroupMembersView.swift
//  SuperDex
//
//  Dedicated sheet for selecting and removing members from a group. Lives in its
//  own view so its selection state can't get tangled with GroupDetailView's.
//

import SwiftUI

struct EditGroupMembersView: View {
    let groupId: UUID
    let accentColor: Color

    @Environment(HomeViewModel.self) private var home
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    private var liveGroup: CardGroup? {
        home.groups.first(where: { $0.id == groupId })
    }

    private var members: [GroupMember] {
        liveGroup?.members ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    if members.isEmpty {
                        emptyState
                            .padding(.top, 80)
                            .padding(.horizontal, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(members) { member in
                                row(for: member)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, selectedIds.isEmpty ? 16 : 110)
                    }
                }
                .background(Color(red: 0.04, green: 0.05, blue: 0.09).ignoresSafeArea())

                if !selectedIds.isEmpty {
                    deleteBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedIds)
            .navigationTitle("Edit Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.04, green: 0.05, blue: 0.09), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert(
                "Remove \(selectedIds.count) Card\(selectedIds.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirmation
            ) {
                Button("Remove", role: .destructive) {
                    home.removeMembers(selectedIds, fromGroupId: groupId)
                    selectedIds.removeAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("They will be removed from this deck.")
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func row(for member: GroupMember) -> some View {
        let isSelected = selectedIds.contains(member.id)
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isSelected ? accentColor : .white.opacity(0.5))

            Image(member.avatar)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !member.jobRole.isEmpty {
                    Text(member.jobRole)
                        .font(.gilroy(.regular, size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isSelected ? accentColor.opacity(0.6) : .white.opacity(0.08),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if isSelected {
                    selectedIds.remove(member.id)
                } else {
                    selectedIds.insert(member.id)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text("No members yet")
                .font(.gilroy(.semiBold, size: 17))
                .foregroundStyle(.white)
            Text("Add members from the deck screen using the + button.")
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var deleteBar: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.gilroy(.semiBold, size: 17))

                Text("Remove \(selectedIds.count) Card\(selectedIds.count == 1 ? "" : "s")")
                    .font(.gilroy(.semiBold, size: 16))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.gilroy(.semiBold, size: 13))
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.red)
            )
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}
