//
//  AddToGroupSheet.swift
//  HomeScreen
//

import SwiftUI

struct AddToGroupSheet: View {
    let members: [GroupMember]
    var onComplete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(HomeViewModel.self) private var home
    @State private var showNewGroup: Bool = false
    @State private var confirmation: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        membersSummary
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        sectionHeader("CREATE NEW")
                        newGroupRow
                            .padding(.horizontal, 20)

                        if !home.groups.isEmpty {
                            sectionHeader("ADD TO EXISTING")

                            VStack(spacing: 10) {
                                ForEach(home.groups) { group in
                                    Button {
                                        add(to: group)
                                    } label: {
                                        groupRow(group: group)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Add to Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showNewGroup) {
                NewGroupView(initialMembers: members) { name, description, date, location, link, wallpaperData, members in
                    home.createGroup(
                        name: name,
                        description: description,
                        eventDate: date,
                        location: location,
                        link: link,
                        wallpaperData: wallpaperData,
                        members: members
                    )
                    finish(message: "Created \(name.trimmingCharacters(in: .whitespaces))")
                }
            }
            .alert(confirmation ?? "", isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            )) {
                Button("OK") {
                    confirmation = nil
                    onComplete()
                    dismiss()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var membersSummary: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                Image(systemName: "person.2.fill")
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(members.count) selected")
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                Text(members.map { $0.name }.joined(separator: ", "))
                    .font(.gilroy(.regular, size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.gilroy(.semiBold, size: 11))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    private var newGroupRow: some View {
        Button {
            showNewGroup = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                    Image(systemName: "plus")
                        .font(.gilroy(.bold, size: 18))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("New Deck")
                        .font(.gilroy(.semiBold, size: 16))
                        .foregroundStyle(.white)
                    Text("Create a deck with selected contacts")
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.gilroy(.semiBold, size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func groupRow(group: CardGroup) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [group.color, group.color.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: group.icon)
                    .font(.gilroy(.semiBold, size: 18))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.gilroy(.semiBold, size: 16))
                    .foregroundStyle(.white)
                Text("\(group.members.count) members")
                    .font(.gilroy(.regular, size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.gilroy(.semiBold, size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func add(to group: CardGroup) {
        let added = home.addMembers(members, toGroupId: group.id)
        finish(message: added == 0
               ? "Already in \(group.name)"
               : "Added \(added) to \(group.name)")
    }

    private func finish(message: String) {
        confirmation = message
    }
}

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            AddToGroupSheet(members: [
                GroupMember(name: "Ben"),
                GroupMember(name: "Sara")
            ])
            .environment(HomeViewModel())
        }
        .preferredColorScheme(.dark)
}
