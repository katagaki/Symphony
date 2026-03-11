import Foundation
import Observation

@Observable
final class WorkflowsManager {
    var workflows: [CiWorkflow] = []
    var buildRunsByWorkflow: [String: [CiBuildRun]] = [:]
    var isLoading: Bool = false
    var isRefreshing: Bool = false
    var error: String?

    let api: AppStoreConnectAPI
    let app: CiApp
    private var productID: String?
    private var refreshTask: Task<Void, Never>?

    init(api: AppStoreConnectAPI, app: CiApp) {
        self.api = api
        self.app = app
    }

    deinit {
        refreshTask?.cancel()
    }

    func loadWorkflows() async {
        isLoading = true
        error = nil
        do {
            let product = try await api.getCiProduct(forAppID: app.id)
            productID = product.id
            workflows = try await api.listWorkflows(forProductID: product.id)
            try await loadBuildRuns(productID: product.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refreshBuildRuns() async {
        guard let productID else { return }
        isRefreshing = true
        do {
            try await loadBuildRuns(productID: productID)
        } catch {
            // Silently fail on background refresh
        }
        isRefreshing = false
    }

    private func loadBuildRuns(productID: String) async throws {
        let buildRuns = try await api.listBuildRuns(forProductID: productID)

        var grouped: [String: [CiBuildRun]] = [:]
        for run in buildRuns {
            if let wfID = run.relationships?.workflow?.data?.id {
                var runs = grouped[wfID] ?? []
                if runs.count < 5 {
                    runs.append(run)
                }
                grouped[wfID] = runs
            }
        }
        buildRunsByWorkflow = grouped
    }

    func cancelBuildRun(id: String) async {
        do {
            try await api.cancelBuildRun(id: id)
            await refreshBuildRuns()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                await self.refreshBuildRuns()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
