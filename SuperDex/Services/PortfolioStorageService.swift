//
//  PortfolioStorageService.swift
//  SuperDex
//

import Foundation
import UIKit
import Supabase

struct PortfolioStorageService {
    private let client = SupabaseManager.client
    private let bucket = "portfolio-images"

    func upload(image: UIImage, userId: UUID) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw PortfolioError.compressionFailed
        }
        let fileName = "\(userId.uuidString)/\(UUID().uuidString).jpg"
        try await client.storage.from(bucket).upload(
            fileName,
            data: data,
            options: .init(contentType: "image/jpeg")
        )
        let publicURL = try client.storage.from(bucket).getPublicURL(path: fileName)
        return publicURL.absoluteString
    }

    func delete(path: String) async throws {
        guard let url = URL(string: path),
              let range = path.range(of: "\(bucket)/") else { return }
        let filePath = String(path[range.upperBound...])
        try await client.storage.from(bucket).remove(paths: [filePath])
    }

    /// Removes every portfolio image under the user's folder. Used during account
    /// deletion, which must clear storage via the API since direct deletes from
    /// `storage.objects` are blocked in Postgres.
    func deleteAll(userId: UUID) async throws {
        let folder = userId.uuidString
        let files = try await client.storage.from(bucket).list(path: folder)
        let paths = files.map { "\(folder)/\($0.name)" }
        guard !paths.isEmpty else { return }
        try await client.storage.from(bucket).remove(paths: paths)
    }

    enum PortfolioError: LocalizedError {
        case compressionFailed
        var errorDescription: String? {
            switch self {
            case .compressionFailed: return "Failed to compress image"
            }
        }
    }
}
