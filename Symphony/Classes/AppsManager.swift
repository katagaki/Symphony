import Foundation
import Observation

@Observable
final class AppsManager {
    var apps: [CiApp] = []
    /// Latest build run per app ID, for apps that have at least one build.
    var latestBuildByApp: [String: CiBuildRun] = [:]
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var error: String?
    /// When the data currently on screen was fetched from the network.
    var lastUpdated: Date?
    /// True when the last refresh failed and the view is showing cached data.
    var isShowingStaleData: Bool = false

    private let api: AppStoreConnectAPI?
    private let isDemoMode: Bool
    private let cacheKey: String?

    init(api: AppStoreConnectAPI, accountID: String?) {
        self.api = api
        self.isDemoMode = false
        self.cacheKey = accountID
    }

    init(demoMode: Bool) {
        self.api = nil
        self.isDemoMode = true
        self.cacheKey = nil
    }

    func loadApps() async {
        error = nil
        if isDemoMode {
            apps = DemoData.apps
            latestBuildByApp = DemoData.apps.reduce(into: [:]) { result, app in
                result[app.id] = DemoData.latestBuildRun(forAppID: app.id)
            }
            return
        }
        guard let api else { return }

        // Show cached data immediately so the view renders without waiting on the network.
        let hadCache = applyCache()
        isLoading = !hadCache
        isRefreshing = hadCache

        do {
            apps = try await api.listApps()
            lastUpdated = .now
            isShowingStaleData = false
            saveCache()
        } catch {
            // Keep showing cached data on failure, but let the view flag it as stale;
            // only surface the error if we have nothing.
            if apps.isEmpty {
                self.error = error.localizedDescription
            } else {
                isShowingStaleData = true
            }
        }
        isLoading = false
        isRefreshing = false

        await loadLatestBuilds()
    }

    /// Fetches the latest build run for every app, a few apps at a time to stay
    /// within API rate limits. Apps whose fetch fails keep their cached status.
    func loadLatestBuilds() async {
        guard let api, !apps.isEmpty else { return }
        let appIDs = apps.map(\.id)
        var latest = latestBuildByApp
        var checkedAppIDs: [String] = []
        let maxConcurrent = 4

        await withTaskGroup(of: (String, Result<CiBuildRun?, Error>).self) { group in
            var pending = appIDs.makeIterator()
            func addNext() {
                guard let appID = pending.next() else { return }
                group.addTask {
                    do {
                        return (appID, .success(try await api.latestBuildRun(forAppID: appID)))
                    } catch {
                        return (appID, .failure(error))
                    }
                }
            }
            for _ in 0..<maxConcurrent { addNext() }
            for await (appID, result) in group {
                switch result {
                case .success(let run):
                    latest[appID] = run
                    checkedAppIDs.append(appID)
                    if let run, let app = apps.first(where: { $0.id == appID }) {
                        AppIconCache.shared.noteBuildRuns([run], for: app, api: api)
                    }
                case .failure(APIError.notFound):
                    // No Xcode Cloud product for this app.
                    latest[appID] = nil
                    checkedAppIDs.append(appID)
                case .failure:
                    break
                }
                latestBuildByApp = latest
                addNext()
            }
        }

        latestBuildByApp = latest.filter { appIDs.contains($0.key) }
        LatestBuildCache.shared.save(latestBuildByApp, forAppIDs: checkedAppIDs)
    }

    // MARK: - Cache

    @discardableResult
    private func applyCache() -> Bool {
        guard apps.isEmpty,
              let cacheKey,
              let cached = AppListCache.shared.load(forAccountID: cacheKey),
              !cached.apps.isEmpty else {
            return !apps.isEmpty
        }
        apps = cached.apps
        lastUpdated = cached.fetchedAt
        latestBuildByApp = LatestBuildCache.shared.load(forAppIDs: cached.apps.map(\.id))
        return true
    }

    private func saveCache() {
        guard let cacheKey, !apps.isEmpty else { return }
        AppListCache.shared.save(apps, forAccountID: cacheKey)
    }
}
