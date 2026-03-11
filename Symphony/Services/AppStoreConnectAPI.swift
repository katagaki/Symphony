import Foundation

actor AppStoreConnectAPI {
    let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    // MARK: - Apps

    func listApps() async throws -> [CiApp] {
        let response: APIListResponse<CiApp> = try await client.get(
            path: "/v1/apps",
            queryItems: [URLQueryItem(name: "fields[apps]", value: "name,bundleId"),
                         URLQueryItem(name: "limit", value: "200")]
        )
        return response.data
    }

    // MARK: - CI Products

    func getCiProduct(forAppID appID: String) async throws -> CiProduct {
        let response: APIResponse<CiProduct> = try await client.get(
            path: "/v1/apps/\(appID)/ciProduct"
        )
        return response.data
    }

    // MARK: - Workflows

    func listWorkflows(forProductID productID: String) async throws -> [CiWorkflow] {
        let response: APIListResponse<CiWorkflow> = try await client.get(
            path: "/v1/ciProducts/\(productID)/workflows"
        )
        return response.data
    }

    func getWorkflow(id: String) async throws -> CiWorkflow {
        let response: APIResponse<CiWorkflow> = try await client.get(
            path: "/v1/ciWorkflows/\(id)",
            queryItems: [URLQueryItem(name: "include", value: "repository")]
        )
        return response.data
    }

    func getWorkflowRepositoryID(workflowID: String) async throws -> String? {
        let workflow = try await getWorkflow(id: workflowID)
        return workflow.relationships?.repository?.data?.id
    }

    // MARK: - Build Runs

    func listBuildRuns(forProductID productID: String, limit: Int = 50) async throws -> [CiBuildRun] {
        let response: APIListResponse<CiBuildRun> = try await client.get(
            path: "/v1/ciProducts/\(productID)/buildRuns",
            queryItems: [URLQueryItem(name: "limit", value: "\(limit)")]
        )
        return response.data
    }

    func listBuildRuns(forWorkflowID workflowID: String, limit: Int = 25) async throws -> [CiBuildRun] {
        let response: APIListResponse<CiBuildRun> = try await client.get(
            path: "/v1/ciWorkflows/\(workflowID)/buildRuns",
            queryItems: [URLQueryItem(name: "limit", value: "\(limit)"),
                         URLQueryItem(name: "sort", value: "-number")]
        )
        return response.data
    }

    func getBuildRun(id: String) async throws -> CiBuildRun {
        let response: APIResponse<CiBuildRun> = try await client.get(
            path: "/v1/ciBuildRuns/\(id)"
        )
        return response.data
    }

    func startBuildRun(workflowID: String, gitReferenceID: String) async throws -> CiBuildRun {
        let body = StartBuildRunRequest(
            data: .init(
                type: "ciBuildRuns",
                relationships: .init(
                    workflow: .init(data: .init(type: "ciWorkflows", id: workflowID)),
                    sourceBranchOrTag: .init(data: .init(type: "scmGitReferences", id: gitReferenceID))
                )
            )
        )
        let response: APIResponse<CiBuildRun> = try await client.post(
            path: "/v1/ciBuildRuns", body: body
        )
        return response.data
    }

    func cancelBuildRun(id: String) async throws {
        try await client.delete(path: "/v1/ciBuildRuns/\(id)")
    }

    // MARK: - Build Actions

    func listBuildActions(forBuildRunID buildRunID: String) async throws -> [CiBuildAction] {
        let response: APIListResponse<CiBuildAction> = try await client.get(
            path: "/v1/ciBuildRuns/\(buildRunID)/actions"
        )
        return response.data
    }

    // MARK: - Artifacts

    func listArtifacts(forBuildActionID actionID: String) async throws -> [CiArtifact] {
        let response: APIListResponse<CiArtifact> = try await client.get(
            path: "/v1/ciBuildActions/\(actionID)/artifacts"
        )
        return response.data
    }

    func downloadArtifact(url: URL) async throws -> Data {
        try await client.getData(url: url)
    }

    // MARK: - Git References

    func listGitReferences(forRepositoryID repoID: String) async throws -> [GitReference] {
        let response: APIListResponse<GitReference> = try await client.get(
            path: "/v1/scmRepositories/\(repoID)/gitReferences",
            queryItems: [URLQueryItem(name: "limit", value: "200")]
        )
        return response.data
    }
}

// MARK: - Request Bodies

nonisolated struct StartBuildRunRequest: Encodable, Sendable {
    let data: RequestData

    nonisolated struct RequestData: Encodable, Sendable {
        let type: String
        let relationships: Relationships
    }

    nonisolated struct Relationships: Encodable, Sendable {
        let workflow: Relationship
        let sourceBranchOrTag: Relationship
    }

    nonisolated struct Relationship: Encodable, Sendable {
        let data: ResourceIdentifier
    }

    nonisolated struct ResourceIdentifier: Encodable, Sendable {
        let type: String
        let id: String
    }
}
