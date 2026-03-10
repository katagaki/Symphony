import Foundation
import Observation

@Observable
final class BuildRunManager {
    var buildRun: CiBuildRun?
    var actions: [CiBuildAction] = []
    var artifacts: [String: [CiArtifact]] = [:]
    var logText: String?
    var gitReferences: [GitReference] = []
    var isLoading: Bool = false
    var isStartingBuild: Bool = false
    var isLoadingLog: Bool = false
    var error: String?

    let api: AppStoreConnectAPI

    init(api: AppStoreConnectAPI) {
        self.api = api
    }

    func loadBuildRun(id: String) async {
        isLoading = true
        error = nil
        do {
            buildRun = try await api.getBuildRun(id: id)
            actions = try await api.listBuildActions(forBuildRunID: id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadGitReferences(workflowID: String) async {
        do {
            if let repoID = try await api.getWorkflowRepositoryID(workflowID: workflowID) {
                gitReferences = try await api.listGitReferences(forRepositoryID: repoID)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startBuild(workflowID: String, gitReferenceID: String) async {
        isStartingBuild = true
        error = nil
        do {
            buildRun = try await api.startBuildRun(
                workflowID: workflowID,
                gitReferenceID: gitReferenceID
            )
        } catch {
            self.error = error.localizedDescription
        }
        isStartingBuild = false
    }

    func pollBuildStatus(id: String) async {
        while buildRun?.attributes.executionProgress != .complete {
            try? await Task.sleep(for: .seconds(10))
            if Task.isCancelled { break }
            do {
                buildRun = try await api.getBuildRun(id: id)
                actions = try await api.listBuildActions(forBuildRunID: id)
            } catch {
                break
            }
        }
    }

    func loadArtifacts(forActionID actionID: String) async {
        do {
            let actionArtifacts = try await api.listArtifacts(forBuildActionID: actionID)
            artifacts[actionID] = actionArtifacts
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadLog(forActionID actionID: String) async {
        isLoadingLog = true
        logText = nil
        do {
            let actionArtifacts = try await api.listArtifacts(forBuildActionID: actionID)

            // Find the log artifact
            if let logArtifact = actionArtifacts.first(where: {
                $0.attributes.fileName?.hasSuffix(".log") == true
                    || $0.attributes.fileName?.contains("log") == true
            }),
               let urlString = logArtifact.attributes.downloadUrl,
               let url = URL(string: urlString) {
                let data = try await api.downloadArtifact(url: url)
                logText = String(data: data, encoding: .utf8) ?? "Unable to decode log content."
            } else {
                logText = "No log artifacts found for this action."
            }
        } catch {
            logText = "Failed to load logs: \(error.localizedDescription)"
        }
        isLoadingLog = false
    }
}
