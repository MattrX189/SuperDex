//
//  CachedAsyncImage.swift
//  SuperDex
//
//  AsyncImage look-alike backed by a two-level cache. AsyncImage
//  refetches every time a row scrolls back on screen (URLCache often
//  misses because event sites send no-cache headers), which made the
//  events list thumbnails slow. This downloads once, downsamples the
//  often multi-megabyte originals, keeps the decoded image in memory
//  and a JPEG on disk — so images survive app relaunches and each URL
//  is fetched from the network at most once.
//

import SwiftUI
import CryptoKit

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loaded: UIImage?

    private var image: UIImage? {
        loaded ?? url.flatMap { ImageCache.shared.cachedImage(for: $0) }
    }

    var body: some View {
        if let image {
            content(Image(uiImage: image))
        } else {
            placeholder()
                .task(id: url) {
                    guard let url else { return }
                    loaded = await ImageCache.shared.load(url)
                }
        }
    }
}

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()

    private let memory: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = 100 * 1024 * 1024 // ~100 MB of decoded pixels
        return cache
    }()

    private let lock = NSLock()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let diskDirectory: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDirectory = caches.appendingPathComponent("EventImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    /// Memory-only, synchronous — lets views skip the placeholder
    /// entirely for already-loaded images.
    func cachedImage(for url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    /// Memory → disk → network, deduping concurrent requests for the
    /// same URL (a prefetch and an on-screen row often race).
    func load(_ url: URL) async -> UIImage? {
        if let image = cachedImage(for: url) { return image }

        lock.lock()
        if let task = inFlight[url] {
            lock.unlock()
            return await task.value
        }
        let task = Task<UIImage?, Never>(priority: .userInitiated) { [weak self] in
            await self?.fetch(url)
        }
        inFlight[url] = task
        lock.unlock()

        let image = await task.value
        lock.lock()
        inFlight[url] = nil
        lock.unlock()
        return image
    }

    /// Fire-and-forget cache warming, e.g. for the first screenful of
    /// thumbnails right after a filter change.
    func prefetch(_ urls: [URL]) {
        for url in urls where cachedImage(for: url) == nil {
            Task(priority: .utility) { _ = await load(url) }
        }
    }

    private func fetch(_ url: URL) async -> UIImage? {
        let file = diskDirectory.appendingPathComponent(Self.fileName(for: url))
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
            store(image, for: url)
            return image
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data)?.downsampled(maxDimension: 1000)
        else { return nil }

        store(image, for: url)
        try? image.jpegData(compressionQuality: 0.8)?.write(to: file)
        return image
    }

    private func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        memory.setObject(image, forKey: url as NSURL, cost: cost)
    }

    private static func fileName(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined() + ".jpg"
    }
}

extension UIImage {
    /// Scales the image down so its longest side is at most
    /// `maxDimension` points — full-res event photos are far larger
    /// than any thumbnail or hero needs, and decoded pixels are what
    /// actually cost memory and scroll performance.
    func downsampled(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return self }
        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
