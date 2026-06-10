import Foundation
import Observation

@Observable
final class AppListCache {
    static let shared = AppListCache()

    private var entries: [String: [CiApp]] = [:]
    private let cacheURL: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("AppListCache.json")
        loadFromDisk()
    }

    func load(forAccountID accountID: String) -> [CiApp]? {
        entries[accountID]
    }

    func save(_ apps: [CiApp], forAccountID accountID: String) {
        entries[accountID] = apps
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
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: [CiApp]].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
