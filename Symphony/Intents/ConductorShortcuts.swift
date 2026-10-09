import AppIntents

struct ConductorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBuildIntent(),
            phrases: [
                "Start a build in \(.applicationName)",
                "Start a \(.applicationName) build of \(\.$app)"
            ],
            shortTitle: "Intents.StartBuild.Title",
            systemImageName: "hammer"
        )
        AppShortcut(
            intent: GetLatestBuildIntent(),
            phrases: [
                "Get the latest build in \(.applicationName)",
                "Get the latest \(.applicationName) build of \(\.$app)"
            ],
            shortTitle: "Intents.LatestBuild.Title",
            systemImageName: "clock.arrow.circlepath"
        )
        AppShortcut(
            intent: OpenAppIntent(),
            phrases: [
                "Open \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Intents.OpenApp.Title",
            systemImageName: "app"
        )
    }
}
