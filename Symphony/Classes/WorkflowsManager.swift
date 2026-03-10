import Foundation
import Observation

@Observable
final class WorkflowsManager {
    var workflows: [CiWorkflow] = []
    var latestBuildRuns: [String: CiBuildRun] = [:]
    var isLoading: Bool = false
    var error: String?

    let api: AppStoreConnectAPI
    let app: CiApp
    private var productID: String?

    init(api: AppStoreConnectAPI, app: CiApp) {
        self.api = api
        self.app = app
    }

    func loadWorkflows() async {
        isLoading = true
        error = nil
        do {
            let product = try await api.getCiProduct(forAppID: app.id)
            productID = product.id
            workflows = try await api.listWorkflows(forProductID: product.id)

            let buildRuns = try await api.listBuildRuns(forProductID: product.id)

            // Map latest build run to each workflow
            var latest: [String: CiBuildRun] = [:]
            for run in buildRuns {
                if let wfID = run.relationships?.workflow?.data?.id {
                    if latest[wfID] == nil {
                        latest[wfID] = run
                    }
                }
            }
            latestBuildRuns = latest
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
