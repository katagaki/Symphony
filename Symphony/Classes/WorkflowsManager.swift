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
        error = nil
        if isDemoMode {
            isLoading = true
            workflows = sortedByName(DemoData.workflows(forAppID: app.id))
            isLoadingBuilds = true
            await loadDemoBuildRuns()
            isLoadingBuilds = false
            isLoading = false
            return
        }

        guard let api else { return }

        // Show cached data immediately so the view renders without waiting on the network.
        let hadCache = applyCache()
        isLoading = !hadCache

        do {
            let product = try await api.getCiProduct(forAppID: app.id)
            productID = product.id
            workflows = sortedByName(try await api.listWorkflows(forProductID: product.id))
            isLoading = false
            isLoadingBuilds = !hadCache
            await loadBuildRunsPerWorkflow()
            isLoadingBuilds = false
            saveCache()
        } catch {
            // Keep showing cached data on failure; only surface the error if we have nothing.
            if !hadCache {
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
        saveCache()
        isRefreshing = false
    }

    private func sortedByName(_ workflows: [CiWorkflow]) -> [CiWorkflow] {
        workflows.sorted {
            $0.attributes.name.localizedCaseInsensitiveCompare($1.attributes.name) == .orderedAscending
        }
    }

    @discardableResult
    private func applyCache() -> Bool {
        guard let cached = WorkflowCache.shared.load(forAppID: app.id),
              !cached.workflows.isEmpty else {
            return false
        }
        productID = cached.productID
        workflows = sortedByName(cached.workflows)
        buildRunsByWorkflow = cached.buildRunsByWorkflow
        branchNamesByBuildRun = cached.branchNamesByBuildRun
        return true
    }

    private func saveCache() {
        guard !isDemoMode, !workflows.isEmpty else { return }
        let cached = CachedAppWorkflows(
            productID: productID,
            workflows: workflows,
            buildRunsByWorkflow: buildRunsByWorkflow,
            branchNamesByBuildRun: branchNamesByBuildRun
        )
        WorkflowCache.shared.save(cached, forAppID: app.id)
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
        // Seed with existing data so a failed per-workflow fetch keeps its cached builds.
        var grouped = buildRunsByWorkflow
        var allBranchNames = branchNamesByBuildRun
        let workflowIDs = Set(workflows.map(\.id))
        await withTaskGroup(of: (String, [CiBuildRun], [String: String])?.self) { group in
            for workflow in workflows {
                group.addTask {
                    guard let result = try? await api.listBuildRuns(forWorkflowID: workflow.id) else {
                        return nil
                    }
                    return (workflow.id, result.runs, result.branchNames)
                }
            }
            for await result in group {
                guard let (workflowID, runs, branchNames) = result else { continue }
                grouped[workflowID] = runs
                allBranchNames.merge(branchNames) { _, new in new }
            }
        }
        // Drop builds for workflows that no longer exist.
        grouped = grouped.filter { workflowIDs.contains($0.key) }
        buildRunsByWorkflow = grouped
        branchNamesByBuildRun = allBranchNames
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
