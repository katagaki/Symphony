import Foundation
import Observation

@Observable
final class AppsManager {
    var apps: [CiApp] = []
    var isLoading: Bool = false
    var error: String?

    private let api: AppStoreConnectAPI

    init(api: AppStoreConnectAPI) {
        self.api = api
    }

    func loadApps() async {
        isLoading = true
        error = nil
        do {
            apps = try await api.listApps()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
