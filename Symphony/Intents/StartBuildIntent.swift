import AppIntents

struct StartBuildIntent: AppIntent {
    static let title: LocalizedStringResource = "Intents.StartBuild.Title"
    static let description = IntentDescription("Intents.StartBuild.Description")

    @Parameter(title: "Intents.Parameter.App")
    var app: AppStoreAppEntity

    @Parameter(title: "Intents.Parameter.Workflow")
    var workflow: WorkflowEntity

    @Parameter(title: "Intents.Parameter.GitReference")
    var gitReference: GitReferenceEntity

    @Dependency private var authManager: AuthenticationManager

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$workflow) of \(\.$app) on \(\.$gitReference)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<BuildRunEntity> & ProvidesDialog {
        let buildRun = try await authManager.intentAPI().startBuildRun(
            workflowID: workflow.id,
            gitReferenceID: gitReference.id
        )
        let entity = BuildRunEntity(buildRun: buildRun)
        return .result(
            value: entity,
            dialog: "Intents.StartBuild.Dialog \(entity.number) \(app.name)"
        )
    }
}
