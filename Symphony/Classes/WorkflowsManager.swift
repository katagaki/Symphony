import Foundation
import Observation

@Observable
final class WorkflowsManager {
    var workflows: [CiWorkflow] = []
    var buildRunsByWorkflow: [String: [CiBuildRun]] = [:]
    var branchNamesByBuildRun: [String: String] = [:]
    var isLoading: Bool = false
    var isLoadingBuilds: Bool = false
    var isRefreshing: Bool = false
    var error: String?

    let api: AppStoreConnectAPI?
    let app: CiApp
    let isDemoMode: Bool
    private var productID: String?
    private var refreshTask: Task<Void, Never>?

    init(api: AppStoreConnectAPI, app: CiApp) {
        self.api = api
        self.app = app
        self.isDemoMode = false
    }

    init(demoMode: Bool, app: CiApp) {
        self.api = nil
        self.app = app
        self.isDemoMode = true
    }

    deinit {
        refreshTask?.cancel()
    }

    func loadWorkflows() async {
        isLoading = true
        error = nil
        if isDemoMode {
            workflows = DemoData.workflows(forAppID: app.id)
            isLoadingBuilds = true
            await loadDemoBuildRuns()
            isLoadingBuilds = false
        } else if let api {
            do {
                let product = try await api.getCiProduct(forAppID: app.id)
                productID = product.id
                workflows = try await api.listWorkflows(forProductID: product.id)
                isLoadingBuilds = true
                await loadBuildRunsPerWorkflow()
                isLoadingBuilds = false
            } catch {
                self.error = error.localizedDescription
            }
        }
        isLoading = false
    }

    func refreshBuildRuns() async {
        if isDemoMode { return }
        guard productID != nil else { return }
        isRefreshing = true
        await loadBuildRunsPerWorkflow()
        isRefreshing = false
    }

    private func loadDemoBuildRuns() async {
        var grouped: [String: [CiBuildRun]] = [:]
        var allBranchNames: [String: String] = [:]
        for workflow in workflows {
            grouped[workflow.id] = DemoData.buildRuns(forWorkflowID: workflow.id)
            allBranchNames.merge(DemoData.branchNames(forWorkflowID: workflow.id)) { _, new in new }
        }
        buildRunsByWorkflow = grouped
        branchNamesByBuildRun = allBranchNames
    }

    private func loadBuildRunsPerWorkflow() async {
        guard let api else { return }
        var grouped: [String: [CiBuildRun]] = [:]
        var allBranchNames: [String: String] = [:]
        await withTaskGroup(of: (String, [CiBuildRun], [String: String]).self) { group in
            for workflow in workflows {
                group.addTask {
                    let result = try? await api.listBuildRuns(forWorkflowID: workflow.id)
                    return (workflow.id, result?.runs ?? [], result?.branchNames ?? [:])
                }
            }
            for await (workflowID, runs, branchNames) in group {
                grouped[workflowID] = runs
                allBranchNames.merge(branchNames) { _, new in new }
            }
        }
        buildRunsByWorkflow = grouped
        branchNamesByBuildRun = allBranchNames
    }

    func cancelBuildRun(id: String) async {
        if isDemoMode { return }
        guard let api else { return }
        do {
            try await api.cancelBuildRun(id: id)
            await refreshBuildRuns()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startAutoRefresh() {
        if isDemoMode { return }
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
