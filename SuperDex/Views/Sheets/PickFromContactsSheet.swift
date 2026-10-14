//
//  PickFromContactsSheet.swift
//  SuperDex
//

import SwiftUI

struct PickFromContactsSheet: View {
    let group: CardGroup

    @Environment(\.dismiss) private var dismiss
    @Environment(HomeViewModel.self) private var home
    @Environment(ContactsViewModel.self) private var contactsVM

    @State private var selectedIds: Set<UUID> = []
    @State private var confirmation: String?

    private var liveGroup: CardGroup {
        home.groups.first(where: { $0.id == group.id }) ?? group
    }

    private var existingMemberKeys: Set<String> {
        Set(liveGroup.members.map { $0.name.lowercased() })
    }

    private var contacts: [Contact] {
        contactsVM.contacts.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var availableContacts: [Contact] {
        contacts.filter { !existingMemberKeys.contains($0.name.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(red: 0.04, green: 0.05, blue: 0.09).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        if availableContacts.isEmpty {
                            emptyState
                                .padding(.top, 60)
                        } else {
                            ForEach(availableContacts) { contact in
                                contactRow(contact)
                            }
                        }

                        Spacer(minLength: selectedIds.isEmpty ? 24 : 110)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                if !selectedIds.isEmpty {
                    addCTA
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedIds)
            .navigationTitle("Add to \(group.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .alert(confirmation ?? "", isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            )) {
                Button("OK") {
                    confirmation = nil
                    dismiss()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Rows

    @ViewBuilder
    private func contactRow(_ contact: Contact) -> some View {
        let isSelected = selectedIds.contains(contact.id)

        Button {
            toggle(contact.id)
        } label: {
            HStack(spacing: 14) {
                Image(contact.avatar)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.gilroy(.semiBold, size: 16))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !contact.jobRole.isEmpty {
                        Text(contact.jobRole)
                            .font(.gilroy(.regular, size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.35))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(isSelected ? 0.30 : 0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var addCTA: some View {
        Button {
            commit()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.2.badge.plus.fill")
                    .font(.gilroy(.semiBold, size: 17))
                Text("Add \(selectedIds.count) to \(group.name)")
                    .font(.gilroy(.semiBold, size: 16))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.gilroy(.semiBold, size: 13))
                    .opacity(0.7)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white)
            )
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.white.opacity(0.4))
            Text(contactsVM.contacts.isEmpty ? "No contacts yet" : "Everyone's already in this deck")
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white.opacity(0.85))
            Text(contactsVM.contacts.isEmpty
                 ? "Scan a card to add your first contact."
                 : "Scan a new card or pick a different deck.")
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func toggle(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func commit() {
        let members = contactsVM.contacts
            .filter { selectedIds.contains($0.id) }
            .map { $0.asGroupMember }
        let added = home.addMembers(members, toGroupId: group.id)
        confirmation = added == 0
            ? "No new members added"
            : "Added \(added) to \(group.name)"
    }
}
