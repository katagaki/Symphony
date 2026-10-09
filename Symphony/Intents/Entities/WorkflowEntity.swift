import AppIntents

struct WorkflowEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Intents.Entity.Workflow"
    static let defaultQuery = WorkflowQuery()

    let id: String
    @Property(title: "Intents.Property.Name")
    var name: String

    init(workflow: CiWorkflow) {
        id = workflow.id
        name = workflow.attributes.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct WorkflowQuery: EntityQuery {
    @Dependency private var authManager: AuthenticationManager
    @IntentParameterDependency<StartBuildIntent>(\.$app)
    private var startBuild

    func entities(for identifiers: [WorkflowEntity.ID]) async throws -> [WorkflowEntity] {
        try await workflows(withIDs: identifiers)
    }

    /// The chosen app's enabled workflows, or every cached workflow before an app is chosen.
    func suggestedEntities() async throws -> [WorkflowEntity] {
        try await suggestedWorkflows(forAppID: startBuild?.app.id)
    }

    @MainActor
    private func workflows(withIDs identifiers: [WorkflowEntity.ID]) async throws -> [WorkflowEntity] {
        let cached = WorkflowCache.shared.allWorkflows().map(\.workflow)
        var result: [WorkflowEntity] = []
        for id in identifiers {
            if let workflow = cached.first(where: { $0.id == id }) {
                result.append(WorkflowEntity(workflow: workflow))
            } else {
                let workflow = try await authManager.intentAPI().getWorkflow(id: id)
                result.append(WorkflowEntity(workflow: workflow))
            }
        }
        return result
    }

    @MainActor
    private func suggestedWorkflows(forAppID appID: String?) async throws -> [WorkflowEntity] {
        let workflows: [CiWorkflow]
        if let appID {
            let api = try authManager.intentAPI()
            let product = try await api.getCiProduct(forAppID: appID)
            workflows = try await api.listWorkflows(forProductID: product.id)
        } else {
            workflows = WorkflowCache.shared.allWorkflows().map(\.workflow)
        }
        return workflows
            .filter { $0.attributes.isEnabled != false }
            .map(WorkflowEntity.init(workflow:))
    }
}
