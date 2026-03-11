import Foundation

enum DemoData {

    // MARK: - Apps

    static let apps: [CiApp] = [
        CiApp(id: "demo-app-xenon", attributes: .init(name: "Xenon", bundleId: "com.yorigami.xenon")),
        CiApp(id: "demo-app-amethyst", attributes: .init(name: "Amethyst", bundleId: "com.yorigami.amethyst")),
        CiApp(id: "demo-app-dahlia", attributes: .init(name: "Dahlia", bundleId: "com.yorigami.dahlia")),
    ]

    // MARK: - Icon Names

    static let iconNames: [String: String] = [
        "com.yorigami.xenon": "App.Xenon",
        "com.yorigami.amethyst": "App.Amethyst",
        "com.yorigami.dahlia": "App.Dahlia",
    ]

    // MARK: - Workflows

    static func workflows(forAppID appID: String) -> [CiWorkflow] {
        switch appID {
        case "demo-app-xenon", "demo-app-amethyst", "demo-app-dahlia":
            return [
                CiWorkflow(
                    id: "\(appID)-workflow-ios",
                    attributes: .init(
                        name: "iOS",
                        description: "Build and test for iOS",
                        lastModifiedDate: "2026-03-01T10:00:00Z",
                        isEnabled: true,
                        isLockedForEditing: false
                    ),
                    relationships: nil
                ),
                CiWorkflow(
                    id: "\(appID)-workflow-macos",
                    attributes: .init(
                        name: "macOS",
                        description: "Build and test for macOS",
                        lastModifiedDate: "2026-03-01T10:00:00Z",
                        isEnabled: true,
                        isLockedForEditing: false
                    ),
                    relationships: nil
                ),
            ]
        default:
            return []
        }
    }

    // MARK: - Build Runs

    static func buildRuns(forWorkflowID workflowID: String) -> [CiBuildRun] {
        switch workflowID {
        // Xenon iOS - 5 builds (2 failed)
        case "demo-app-xenon-workflow-ios":
            return xenonIOSBuilds
        // Xenon macOS - 5 builds (2 failed)
        case "demo-app-xenon-workflow-macos":
            return xenonMacOSBuilds
        // Amethyst iOS - 1 build
        case "demo-app-amethyst-workflow-ios":
            return amethystIOSBuilds
        // Amethyst macOS - 1 build
        case "demo-app-amethyst-workflow-macos":
            return amethystMacOSBuilds
        // Dahlia iOS - 3 builds
        case "demo-app-dahlia-workflow-ios":
            return dahliaIOSBuilds
        // Dahlia macOS - 3 builds
        case "demo-app-dahlia-workflow-macos":
            return dahliaMacOSBuilds
        default:
            return []
        }
    }

    static func branchNames(forWorkflowID workflowID: String) -> [String: String] {
        var result: [String: String] = [:]
        for build in buildRuns(forWorkflowID: workflowID) {
            result[build.id] = "main"
        }
        return result
    }

    // MARK: - Build Actions

    static func buildActions(forBuildRunID buildRunID: String) -> [CiBuildAction] {
        // Determine status from build run
        let allBuilds = xenonIOSBuilds + xenonMacOSBuilds
            + amethystIOSBuilds + amethystMacOSBuilds
            + dahliaIOSBuilds + dahliaMacOSBuilds
        guard let build = allBuilds.first(where: { $0.id == buildRunID }) else {
            return []
        }
        let isFailed = build.attributes.completionStatus == .failed
        return [
            CiBuildAction(
                id: "\(buildRunID)-action-build",
                attributes: .init(
                    name: "Build",
                    actionType: "BUILD",
                    executionProgress: .complete,
                    completionStatus: isFailed ? .failed : .succeeded,
                    startedDate: build.attributes.startedDate,
                    finishedDate: build.attributes.finishedDate,
                    issueCounts: isFailed
                        ? .init(analyzerWarnings: 0, errors: 1, testFailures: 0, warnings: 0)
                        : .init(analyzerWarnings: 0, errors: 0, testFailures: 0, warnings: 0)
                )
            ),
            CiBuildAction(
                id: "\(buildRunID)-action-test",
                attributes: .init(
                    name: "Test",
                    actionType: "TEST",
                    executionProgress: .complete,
                    completionStatus: isFailed ? .failed : .succeeded,
                    startedDate: build.attributes.startedDate,
                    finishedDate: build.attributes.finishedDate,
                    issueCounts: isFailed
                        ? .init(analyzerWarnings: 0, errors: 0, testFailures: 2, warnings: 0)
                        : .init(analyzerWarnings: 0, errors: 0, testFailures: 0, warnings: 0)
                )
            ),
        ]
    }

    // MARK: - Xenon Builds (5 each, 2 failed)

    private static let xenonIOSBuilds: [CiBuildRun] = [
        makeBuild(id: "xenon-ios-1", number: 5, status: .succeeded,
                  date: "2026-03-10T14:00:00Z", message: "Update dependencies"),
        makeBuild(id: "xenon-ios-2", number: 4, status: .failed,
                  date: "2026-03-09T11:30:00Z", message: "Refactor networking layer"),
        makeBuild(id: "xenon-ios-3", number: 3, status: .succeeded,
                  date: "2026-03-08T09:00:00Z", message: "Add push notifications"),
        makeBuild(id: "xenon-ios-4", number: 2, status: .failed,
                  date: "2026-03-07T16:45:00Z", message: "Fix memory leak in image cache"),
        makeBuild(id: "xenon-ios-5", number: 1, status: .succeeded,
                  date: "2026-03-06T08:00:00Z", message: "Initial commit"),
    ]

    private static let xenonMacOSBuilds: [CiBuildRun] = [
        makeBuild(id: "xenon-macos-1", number: 5, status: .succeeded,
                  date: "2026-03-10T14:30:00Z", message: "Update dependencies"),
        makeBuild(id: "xenon-macos-2", number: 4, status: .failed,
                  date: "2026-03-09T12:00:00Z", message: "Refactor networking layer"),
        makeBuild(id: "xenon-macos-3", number: 3, status: .succeeded,
                  date: "2026-03-08T09:30:00Z", message: "Add push notifications"),
        makeBuild(id: "xenon-macos-4", number: 2, status: .failed,
                  date: "2026-03-07T17:00:00Z", message: "Fix memory leak in image cache"),
        makeBuild(id: "xenon-macos-5", number: 1, status: .succeeded,
                  date: "2026-03-06T08:30:00Z", message: "Initial commit"),
    ]

    // MARK: - Amethyst Builds (1 each)

    private static let amethystIOSBuilds: [CiBuildRun] = [
        makeBuild(id: "amethyst-ios-1", number: 1, status: .succeeded,
                  date: "2026-03-10T10:00:00Z", message: "Initial release"),
    ]

    private static let amethystMacOSBuilds: [CiBuildRun] = [
        makeBuild(id: "amethyst-macos-1", number: 1, status: .succeeded,
                  date: "2026-03-10T10:30:00Z", message: "Initial release"),
    ]

    // MARK: - Dahlia Builds (3 each)

    private static let dahliaIOSBuilds: [CiBuildRun] = [
        makeBuild(id: "dahlia-ios-1", number: 3, status: .succeeded,
                  date: "2026-03-10T15:00:00Z", message: "Improve accessibility"),
        makeBuild(id: "dahlia-ios-2", number: 2, status: .succeeded,
                  date: "2026-03-09T13:00:00Z", message: "Add dark mode support"),
        makeBuild(id: "dahlia-ios-3", number: 1, status: .succeeded,
                  date: "2026-03-08T10:00:00Z", message: "Initial commit"),
    ]

    private static let dahliaMacOSBuilds: [CiBuildRun] = [
        makeBuild(id: "dahlia-macos-1", number: 3, status: .succeeded,
                  date: "2026-03-10T15:30:00Z", message: "Improve accessibility"),
        makeBuild(id: "dahlia-macos-2", number: 2, status: .succeeded,
                  date: "2026-03-09T13:30:00Z", message: "Add dark mode support"),
        makeBuild(id: "dahlia-macos-3", number: 1, status: .succeeded,
                  date: "2026-03-08T10:30:00Z", message: "Initial commit"),
    ]

    // MARK: - Helpers

    private static func makeBuild(
        id: String, number: Int, status: CompletionStatus,
        date: String, message: String
    ) -> CiBuildRun {
        CiBuildRun(
            id: "demo-build-\(id)",
            attributes: .init(
                number: number,
                createdDate: date,
                startedDate: date,
                finishedDate: date,
                sourceCommit: .init(
                    commitSha: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40)),
                    message: message,
                    author: .init(displayName: "Demo User")
                ),
                executionProgress: .complete,
                completionStatus: status,
                isPullRequestBuild: false
            ),
            relationships: nil
        )
    }
}
