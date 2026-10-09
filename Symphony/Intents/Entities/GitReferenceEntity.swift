import AppIntents

struct GitReferenceEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Intents.Entity.GitReference"
    static let defaultQuery = GitReferenceQuery()

    let id: String
    @Property(title: "Intents.Property.Name")
    var name: String
    let isTag: Bool

    init(reference: GitReference) {
        id = reference.id
        isTag = reference.attributes.kind == .tag
        name = reference.attributes.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: isTag ? "tag" : "arrow.triangle.branch")
        )
    }
}

struct GitReferenceQuery: EntityStringQuery {
    @Dependency private var authManager: AuthenticationManager
    @IntentParameterDependency<StartBuildIntent>(\.$workflow)
    private var startBuild

    func entities(for identifiers: [GitReferenceEntity.ID]) async throws -> [GitReferenceEntity] {
        try await references().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [GitReferenceEntity] {
        try await references().filter { $0.name.localizedStandardContains(string) }
    }

    func suggestedEntities() async throws -> [GitReferenceEntity] {
        try await references()
    }

    /// The branches and tags of the chosen workflow's repository, branches first.
    @MainActor
    private func references() async throws -> [GitReferenceEntity] {
        guard let workflowID = startBuild?.workflow.id else { return [] }
        let api = try authManager.intentAPI()
        guard let repoID = try await api.getWorkflowRepositoryID(workflowID: workflowID) else {
            throw IntentError.noRepository
        }
        return try await api.listGitReferences(forRepositoryID: repoID)
            .filter { $0.attributes.isDeleted != true }
            .map(GitReferenceEntity.init(reference:))
            .sorted { !$0.isTag && $1.isTag }
    }
}
