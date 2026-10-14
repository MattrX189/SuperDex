//
//  GigsScreen.swift
//  SuperDex
//
//  Dedicated Gigs page, pushed from Discover's "See all". Full feed
//  with search, category filters and posting.
//

import SwiftUI

struct GigsScreen: View {
    let viewModel: GigsViewModel

    @Environment(BlockStore.self) private var blockStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var selectedCategory: ProfileCategory? = nil
    @State private var selectedGig: GigPost?
    @State private var showComposer = false
    @FocusState private var isSearchFocused: Bool

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredGigs: [GigPost] {
        // Blocked users' posts vanish instantly (Guideline 1.2).
        var result = viewModel.posts.filter { !blockStore.isBlocked($0.userId) }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return result }
        return result.filter { post in
            post.title.localizedCaseInsensitiveContains(query)
            || post.descriptionText.localizedCaseInsensitiveContains(query)
            || post.posterFullName.localizedCaseInsensitiveContains(query)
            || (post.location?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    navBar
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    categoryChips
                        .padding(.bottom, 18)

                    postRequirementButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)

                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        loadingState
                            .padding(.top, 60)
                    } else if viewModel.posts.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else if filteredGigs.isEmpty {
                        noResultsState
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredGigs) { post in
                                GigCardView(
                                    post: post,
                                    isOwn: post.isOwn(viewModel.currentUserId)
                                )
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedGig = post
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .navigationBarHidden(true)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedCategory)
        .navigationDestination(item: $selectedGig) { post in
            GigDetailView(post: post, viewModel: viewModel)
        }
        .sheet(isPresented: $showComposer) {
            GigComposerSheet(viewModel: viewModel)
        }
    }

    // MARK: - Nav bar (chevron left, title centered inline)

    private var navBar: some View {
        ZStack {
            Text("Opportunities")
                .font(.gilroy(.bold, size: 20))
                .foregroundStyle(.white)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .contentShape(Circle())
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    // MARK: - Post button

    // Styled like HomeView's "Create your first group" prompt row.
    private var postRequirementButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showComposer = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.25))
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.indigo)
                }
                .frame(width: 40, height: 40)

                Text("Post a Requirement")
                    .font(.gilroy(.semiBold, size: 15))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            TextField(
                "",
                text: $searchText,
                prompt: Text("Search opportunities by title, skill, location")
                    .font(.gilroy(.regular, size: 15))
                    .foregroundColor(.white.opacity(0.55))
            )
            .font(.gilroy(.regular, size: 16))
            .foregroundStyle(.white)
            .tint(.white)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
            .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isSearchFocused ? 0.10 : 0.06))
        )
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: isSearchFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: searchText.isEmpty)
        .contentShape(Capsule(style: .continuous))
        .onTapGesture { isSearchFocused = true }
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ProfileCategory.allCases) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedCategory = isSelected ? nil : category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(category.displayName)
                                .font(.gilroy(.semiBold, size: 13))
                        }
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(isSelected
                                      ? AnyShapeStyle(.white)
                                      : AnyShapeStyle(.white.opacity(0.08)))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? .clear : .white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white.opacity(0.7))
            Text("Finding opportunities…")
                .font(.gilroy(.medium, size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "briefcase")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.35))

            Text(viewModel.loadFailed ? "Couldn't load opportunities" : "No opportunities yet")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))

            Text(viewModel.loadFailed
                ? "Check your connection and pull to refresh."
                : "Be the first to post a requirement — designers, developers, marketers and more are here.")
                .font(.gilroy(.regular, size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.gilroy(.regular, size: 38))
                .foregroundStyle(.white.opacity(0.35))

            Text("No matches")
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.8))

            if let category = selectedCategory {
                Text("No opportunities found in \(category.displayName).")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else {
                Text("No opportunities match \"\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))\".")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                if isSearching {
                    Button("Clear search") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        searchText = ""
                    }
                    .font(.gilroy(.semiBold, size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }

                if selectedCategory != nil {
                    Button("Clear filter") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedCategory = nil
                        }
                    }
                    .font(.gilroy(.semiBold, size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }
}
