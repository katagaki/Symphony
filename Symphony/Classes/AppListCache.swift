import Foundation
import Observation

nonisolated struct CachedAppList: Codable, Sendable {
    var apps: [CiApp]
    var fetchedAt: Date
}

@Observable
final class AppListCache {
    static let shared = AppListCache()

    private var entries: [String: CachedAppList] = [:]
    private let cacheURL: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("AppListCache.json")
        loadFromDisk()
    }

    func load(forAccountID accountID: String) -> CachedAppList? {
        entries[accountID]
    }

    func save(_ apps: [CiApp], forAccountID accountID: String) {
        entries[accountID] = CachedAppList(apps: apps, fetchedAt: .now)
        saveToDisk()
    }

    func remove(forAccountID accountID: String) {
        entries.removeValue(forKey: accountID)
        saveToDisk()
    }

    func clearAll() {
        entries.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        if let decoded = try? JSONDecoder().decode([String: CachedAppList].self, from: data) {
            entries = decoded
        } else if let legacy = try? JSONDecoder().decode([String: [CiApp]].self, from: data) {
            // Migrate the pre-timestamp format; the file's modification date is the
            // closest approximation of when the data was fetched.
            let modified = (try? FileManager.default.attributesOfItem(atPath: cacheURL.path))?[.modificationDate] as? Date
            entries = legacy.mapValues { CachedAppList(apps: $0, fetchedAt: modified ?? .distantPast) }
        }
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
