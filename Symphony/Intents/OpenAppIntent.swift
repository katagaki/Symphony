import AppIntents

struct OpenAppIntent: OpenIntent {
    static let title: LocalizedStringResource = "Intents.OpenApp.Title"
    static let description = IntentDescription("Intents.OpenApp.Description")

    @Parameter(title: "Intents.Parameter.App")
    var target: AppStoreAppEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentNavigator.shared.pendingApp = target.app
        return .result()
    }
}
