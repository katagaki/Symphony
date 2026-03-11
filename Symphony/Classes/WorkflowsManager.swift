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
            await loadBuildRunsPerWorkflow()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refreshBuildRuns() async {
        guard productID != nil else { return }
        isRefreshing = true
        await loadBuildRunsPerWorkflow()
        isRefreshing = false
    }

    private func loadBuildRunsPerWorkflow() async {
        var grouped: [String: [CiBuildRun]] = [:]
        await withTaskGroup(of: (String, [CiBuildRun]).self) { group in
            for workflow in workflows {
                group.addTask {
                    let runs = (try? await self.api.listBuildRuns(forWorkflowID: workflow.id)) ?? []
                    return (workflow.id, runs)
                }
            }
            for await (workflowID, runs) in group {
                grouped[workflowID] = runs
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
