import Foundation
import SwiftUI

@Observable
final class AppIconCache {
    static let shared = AppIconCache()

    private struct CacheEntry: Codable {
        let urlString: String
        var lastAccessed: Date
    }

    private var entries: [String: CacheEntry] = [:]
    private let cacheURL: URL
    private let ttl: TimeInterval = 3600 // 1 hour

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("AppIconCache.json")
        loadFromDisk()
        pruneExpired()
    }

    func iconURL(for bundleId: String, forceRefresh: Bool = false) async -> URL? {
        if !forceRefresh, let entry = entries[bundleId] {
            entries[bundleId]?.lastAccessed = Date()
            saveToDisk()
            return URL(string: entry.urlString)
        }

        guard let url = await fetchIconURL(bundleId: bundleId) else { return nil }
        entries[bundleId] = CacheEntry(urlString: url.absoluteString, lastAccessed: Date())
        saveToDisk()
        return url
    }

    func clearAll() {
        entries.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func pruneExpired() {
        let now = Date()
        entries = entries.filter { now.timeIntervalSince($0.value.lastAccessed) < ttl }
        saveToDisk()
    }

    // MARK: - Network

    private func fetchIconURL(bundleId: String) async -> URL? {
        guard let lookupURL = URL(
            string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)"
        ) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: lookupURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let results = json?["results"] as? [[String: Any]]
            if let artworkString = results?.first?["artworkUrl512"] as? String,
               let url = URL(string: artworkString) {
                return url
            }
        } catch {
            // Fall through to return nil
        }
        return nil
    }
}
