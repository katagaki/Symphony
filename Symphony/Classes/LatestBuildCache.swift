import Foundation
import Observation

@Observable
final class LatestBuildCache {
    static let shared = LatestBuildCache()

    private var entries: [String: CiBuildRun] = [:]
    private let cacheURL: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("LatestBuildCache.json")
        loadFromDisk()
    }

    func load(forAppIDs appIDs: [String]) -> [String: CiBuildRun] {
        entries.filter { appIDs.contains($0.key) }
    }

    func save(_ builds: [String: CiBuildRun], forAppIDs appIDs: [String]) {
        // Replace entries for every app that was checked so apps whose builds are
        // gone don't keep a stale status.
        for appID in appIDs {
            entries[appID] = builds[appID]
        }
        saveToDisk()
    }

    func remove(forAppIDs appIDs: [String]) {
        guard !appIDs.isEmpty else { return }
        for appID in appIDs {
            entries.removeValue(forKey: appID)
        }
        saveToDisk()
    }

    func clearAll() {
        entries.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: CiBuildRun].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
