import Foundation
import Observation

@Observable
final class AppsManager {
    var apps: [CiApp] = []
    var isLoading: Bool = false
    var error: String?

    private let api: AppStoreConnectAPI?
    private let isDemoMode: Bool

    init(api: AppStoreConnectAPI) {
        self.api = api
        self.isDemoMode = false
    }

    init(demoMode: Bool) {
        self.api = nil
        self.isDemoMode = true
    }

    func loadApps() async {
        isLoading = true
        error = nil
        if isDemoMode {
            apps = DemoData.apps
        } else if let api {
            do {
                apps = try await api.listApps()
            } catch {
                self.error = error.localizedDescription
            }
        }
        isLoading = false
    }
}
