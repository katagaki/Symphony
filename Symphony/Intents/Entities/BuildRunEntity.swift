import AppIntents

struct BuildRunEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Intents.Entity.BuildRun"
    static let defaultQuery = BuildRunQuery()

    let id: String
    @Property(title: "Intents.Property.Number")
    var number: Int
    @Property(title: "Intents.Property.Status")
    var status: String
    @Property(title: "Intents.Property.CommitMessage")
    var commitMessage: String?
    @Property(title: "Intents.Property.Author")
    var author: String?

    init(buildRun: CiBuildRun) {
        id = buildRun.id
        number = buildRun.attributes.number ?? 0
        status = BuildStatusBadge(
            progress: buildRun.attributes.executionProgress,
            status: buildRun.attributes.completionStatus
        ).labelText
        commitMessage = buildRun.attributes.sourceCommit?.message?
            .components(separatedBy: .newlines).first
        author = buildRun.attributes.sourceCommit?.author?.displayName
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Intents.BuildRun.Title \(number)",
            subtitle: "\(status)"
        )
    }
}

struct BuildRunQuery: EntityQuery {
    @Dependency private var authManager: AuthenticationManager

    func entities(for identifiers: [BuildRunEntity.ID]) async throws -> [BuildRunEntity] {
        let api = try await authManager.intentAPI()
        var result: [BuildRunEntity] = []
        for id in identifiers {
            result.append(BuildRunEntity(buildRun: try await api.getBuildRun(id: id)))
        }
        return result
    }
}
