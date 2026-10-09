import Foundation
import SwiftUI

/// Caches app icon URLs. Icons come from the app's latest uploaded build, falling back to
/// the iTunes lookup API for apps that have never had a build icon. Build lookups count
/// toward the App Store Connect hourly quota, so they are rate limited and skipped
/// entirely when the quota runs low.
@Observable
final class AppIconCache {
    static let shared = AppIconCache()

    private enum Source: String, Codable {
        case build
        case iTunes
    }

    private struct CacheEntry: Codable {
        /// nil when no icon was found, so the lookup isn't repeated on every appearance.
        var urlString: String?
        var fetchedAt: Date
        /// nil for entries cached before build icons were supported, which came from iTunes.
        var source: Source?
        /// When the app's uploaded builds were last queried successfully.
        var buildsCheckedAt: Date?
        /// Finish date of the newest successful build run whose builds have been checked.
        var handledRunFinishedAt: Date?
    }

    private var entries: [String: CacheEntry] = [:]
    private var inFlight: [String: Task<Void, Never>] = [:]
    private var lastBuildAttempt: [String: Date] = [:]
    private let cacheURL: URL

    private let iconSize = 512
    private let iTunesTTL: TimeInterval = 24 * 3600
    // Apps without a build icon yet are rechecked daily in case they gain one.
    private let buildRecheckInterval: TimeInterval = 24 * 3600
    // New icons normally arrive via noteBuildRuns; this catches successful runs it never saw.
    private let buildIconTTL: TimeInterval = 7 * 24 * 3600
    private let forcedBuildRecheckInterval: TimeInterval = 15 * 60
    private let buildRetryInterval: TimeInterval = 5 * 60
    // How long after a run finishes its build may still be processing without an icon.
    private let processingGracePeriod: TimeInterval = 2 * 3600
    private let maxAge: TimeInterval = 7 * 24 * 3600 // Drop iTunes entries untouched for a week.

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("AppIconCache.json")
        loadFromDisk()
        pruneExpired()
    }

    /// The cached icon URL. Views reading this re-render when the icon changes.
    func cachedIconURL(forBundleID bundleId: String) -> URL? {
        entries[bundleId]?.urlString.flatMap(URL.init(string:))
    }

    /// Refreshes the app's icon if the cached one is missing or due for a recheck.
    func loadIcon(for app: CiApp, api: AppStoreConnectAPI?, forceRefresh: Bool = false) async {
        await deduplicated(app.attributes.bundleId) {
            await self.refresh(app: app, api: api, forceRefresh: forceRefresh)
        }
    }

    /// Checks build runs fetched elsewhere for a successful run newer than the current icon,
    /// and if there is one, fetches the icon from the builds it uploaded. Runs already
    /// handled cost no requests, so this is safe to call on every build list refresh.
    func noteBuildRuns(_ runs: [CiBuildRun], for app: CiApp, api: AppStoreConnectAPI) {
        let key = app.attributes.bundleId
        let succeeded = runs.compactMap { run -> (CiBuildRun, Date)? in
            guard run.attributes.completionStatus == .succeeded,
                  let finishedAt = run.attributes.finishedDate.flatMap(Self.parseDate) else { return nil }
            return (run, finishedAt)
        }
        // Apps seen for the first time get their icon from loadIcon instead.
        guard let (run, finishedAt) = succeeded.max(by: { $0.1 < $1.1 }),
              var entry = entries[key] else { return }
        if let handled = entry.handledRunFinishedAt, handled >= finishedAt { return }

        // A check of the app's builds made well after the run finished already covered it.
        if let checked = entry.buildsCheckedAt, checked > finishedAt.addingTimeInterval(processingGracePeriod) {
            entry.handledRunFinishedAt = finishedAt
            entries[key] = entry
            saveToDisk()
            return
        }
        guard inFlight[key] == nil, canAttemptBuildFetch(key) else { return }
        Task {
            await deduplicated(key) {
                await self.refreshFromRun(run, finishedAt: finishedAt, key: key, api: api)
            }
        }
    }

    func clearAll() {
        entries.removeAll()
        saveToDisk()
    }

    // MARK: - Refreshing

    private func deduplicated(_ key: String, _ operation: @escaping () async -> Void) async {
        if let task = inFlight[key] {
            await task.value
            return
        }
        let task = Task { await operation() }
        inFlight[key] = task
        await task.value
        inFlight[key] = nil
    }

    private func refresh(app: CiApp, api: AppStoreConnectAPI?, forceRefresh: Bool) async {
        let key = app.attributes.bundleId

        if let api, needsBuildCheck(key, forceRefresh: forceRefresh),
           await api.hasBudgetForBackgroundRequests() {
            lastBuildAttempt[key] = .now
            do {
                let build = try await api.latestProcessedBuild(forAppID: app.id)
                var entry = entries[key] ?? CacheEntry(urlString: nil, fetchedAt: .distantPast)
                entry.buildsCheckedAt = .now
                if let url = build?.attributes.iconAssetToken?.url(size: iconSize) {
                    entry.urlString = url.absoluteString
                    entry.fetchedAt = .now
                    entry.source = .build
                }
                entries[key] = entry
                saveToDisk()
            } catch {
                // Retry later; meanwhile serve whatever is cached.
            }
        }

        // An icon from a build is kept even once that build is too old to fetch.
        if entries[key]?.source == .build { return }

        if let entry = entries[key], !forceRefresh,
           Date().timeIntervalSince(entry.fetchedAt) < iTunesTTL {
            return
        }
        do {
            let url = try await fetchITunesIconURL(bundleId: key)
            var entry = entries[key] ?? CacheEntry(urlString: nil, fetchedAt: .now)
            // Keep serving the previous URL if the app is no longer found.
            entry.urlString = url?.absoluteString ?? entry.urlString
            entry.fetchedAt = .now
            entry.source = .iTunes
            entries[key] = entry
            saveToDisk()
        } catch {
            // The refresh failed; keep serving the stale URL rather than dropping the icon.
        }
    }

    private func refreshFromRun(_ run: CiBuildRun, finishedAt: Date, key: String, api: AppStoreConnectAPI) async {
        guard await api.hasBudgetForBackgroundRequests() else { return }
        lastBuildAttempt[key] = .now
        guard let builds = try? await api.listBuilds(forBuildRunID: run.id),
              var entry = entries[key] else { return }

        if let url = builds.lazy.compactMap({ $0.attributes.iconAssetToken?.url(size: self.iconSize) }).first {
            entry.urlString = url.absoluteString
            entry.fetchedAt = .now
            entry.source = .build
            entry.handledRunFinishedAt = finishedAt
        } else if builds.isEmpty || Date() > finishedAt.addingTimeInterval(processingGracePeriod) {
            // Nothing was uploaded (e.g. a test-only workflow), or processing never produced an icon.
            entry.handledRunFinishedAt = finishedAt
        } else {
            // Still processing; try again the next time build runs are noted.
            return
        }
        entries[key] = entry
        saveToDisk()
    }

    private func canAttemptBuildFetch(_ key: String) -> Bool {
        guard let last = lastBuildAttempt[key] else { return true }
        return Date().timeIntervalSince(last) >= buildRetryInterval
    }

    private func needsBuildCheck(_ key: String, forceRefresh: Bool) -> Bool {
        guard canAttemptBuildFetch(key) else { return false }
        guard let entry = entries[key], let checked = entry.buildsCheckedAt else { return true }
        let interval: TimeInterval
        if forceRefresh {
            interval = forcedBuildRecheckInterval
        } else if entry.source == .build {
            interval = buildIconTTL
        } else {
            interval = buildRecheckInterval
        }
        return Date().timeIntervalSince(checked) >= interval
    }

    private nonisolated static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
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
        // Build icons are never pruned: once their build ages out they can't be fetched again.
        let pruned = entries.filter {
            $0.value.source == .build || now.timeIntervalSince($0.value.fetchedAt) < maxAge
        }
        guard pruned.count != entries.count else { return }
        entries = pruned
        saveToDisk()
    }

    // MARK: - Network

    /// Returns nil when the app isn't on the App Store; throws on network failure.
    private func fetchITunesIconURL(bundleId: String) async throws -> URL? {
        guard let lookupURL = URL(
            string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)"
        ) else { return nil }

        let (data, _) = try await URLSession.shared.data(from: lookupURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let results = json?["results"] as? [[String: Any]]
        if let artworkString = results?.first?["artworkUrl512"] as? String {
            return URL(string: artworkString)
        }
        return nil
    }
}
