import AppIntents

struct GetLatestBuildIntent: AppIntent {
    static let title: LocalizedStringResource = "Intents.LatestBuild.Title"
    static let description = IntentDescription("Intents.LatestBuild.Description")

    @Parameter(title: "Intents.Parameter.App")
    var app: AppStoreAppEntity

    @Dependency private var authManager: AuthenticationManager

    static var parameterSummary: some ParameterSummary {
        Summary("Get the latest build of \(\.$app)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<BuildRunEntity?> & ProvidesDialog {
        let buildRun: CiBuildRun?
        do {
            buildRun = try await authManager.intentAPI().latestBuildRun(forAppID: app.id)
        } catch APIError.notFound {
            // No Xcode Cloud product for this app.
            buildRun = nil
        }
        guard let buildRun else {
            return .result(value: nil, dialog: "Intents.LatestBuild.NoBuilds \(app.name)")
        }
        let entity = BuildRunEntity(buildRun: buildRun)
        return .result(
            value: entity,
            dialog: "Intents.LatestBuild.Dialog \(entity.number) \(app.name) \(entity.status)"
        )
    }
}
