//
//  GigsViewModel.swift
//  SuperDex
//
//  Loads the gigs feed for the Discover tab and handles posting,
//  applying, and post management for the signed-in user.
//

import SwiftUI

@Observable
@MainActor
final class GigsViewModel {
    var posts: [GigPost] = []
    var isLoading = false
    var loadFailed = false

    private let service = GigService()
    private var hasLoaded = false
    private(set) var currentUserId: UUID?

    func loadIfNeeded(userId: UUID?) async {
        currentUserId = userId
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        if let fetched = await service.fetchPosts() {
            posts = fetched
            loadFailed = false
            hasLoaded = true
        } else if posts.isEmpty {
            loadFailed = true
        }
    }

    func createPost(
        title: String,
        description: String,
        category: ProfileCategory,
        budgetText: String?,
        durationText: String?,
        location: String?
    ) async throws {
        guard let userId = currentUserId else { return }
        try await service.createPost(
            userId: userId,
            title: title,
            description: description,
            category: category,
            budgetText: budgetText,
            durationText: durationText,
            location: location
        )
        await refresh()
    }

    func updatePost(
        postId: UUID,
        title: String,
        description: String,
        category: ProfileCategory,
        budgetText: String?,
        durationText: String?,
        location: String?
    ) async throws {
        try await service.updatePost(
            postId: postId,
            title: title,
            description: description,
            category: category,
            budgetText: budgetText,
            durationText: durationText,
            location: location
        )
        await refresh()
    }

    /// Applies and updates the post in place so the button flips to
    /// "Applied" immediately. Rethrows the server's rejection message.
    func apply(to post: GigPost, message: String?) async throws {
        try await service.apply(postId: post.id, message: message)
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].hasApplied = true
            posts[index].applicantCount += 1
        }
    }

    func withdraw(from post: GigPost) async {
        guard let userId = currentUserId else { return }
        try? await service.withdraw(postId: post.id, userId: userId)
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].hasApplied = false
            posts[index].applicantCount = max(0, posts[index].applicantCount - 1)
        }
    }

    func closePost(_ post: GigPost) async {
        try? await service.closePost(postId: post.id)
        posts.removeAll { $0.id == post.id }
    }

    func deletePost(_ post: GigPost) async {
        try? await service.deletePost(postId: post.id)
        posts.removeAll { $0.id == post.id }
    }

    func fetchApplicants(for post: GigPost) async -> [GigApplicant]? {
        await service.fetchApplicants(postId: post.id)
    }
}
