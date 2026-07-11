import Foundation
import Observation

@Observable
final class AppsManager {
    var apps: [CiApp] = []
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
        return true
    }

    private func saveCache() {
        guard let cacheKey, !apps.isEmpty else { return }
        AppListCache.shared.save(apps, forAccountID: cacheKey)
    }
}
