import Foundation
import Observation

nonisolated struct CachedAppWorkflows: Codable, Sendable {
    var productID: String?
    var workflows: [CiWorkflow]
    var buildRunsByWorkflow: [String: [CiBuildRun]]
    var branchNamesByBuildRun: [String: String]
    // Optional so entries written before timestamps were introduced still decode.
    var fetchedAt: Date?
}

@Observable
final class WorkflowCache {
    static let shared = WorkflowCache()

    private var entries: [String: CachedAppWorkflows] = [:]
    private let cacheURL: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("WorkflowCache.json")
        loadFromDisk()
    }

    func load(forAppID appID: String) -> CachedAppWorkflows? {
        entries[appID]
    }

    func save(_ cached: CachedAppWorkflows, forAppID appID: String) {
        entries[appID] = cached
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
              let decoded = try? JSONDecoder().decode([String: CachedAppWorkflows].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
