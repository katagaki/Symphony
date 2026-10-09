import Foundation

enum DemoData {

    // MARK: - Apps

    static let apps: [CiApp] = [
        CiApp(id: "demo-app-xenon", attributes: .init(name: "Xenon", bundleId: "com.yorigami.xenon")),
        CiApp(id: "demo-app-amethyst", attributes: .init(name: "Amethyst", bundleId: "com.yorigami.amethyst")),
        CiApp(id: "demo-app-dahlia", attributes: .init(name: "Dahlia", bundleId: "com.yorigami.dahlia")),
        CiApp(id: "demo-app-sirius", attributes: .init(name: "Sirius", bundleId: "com.yorigami.sirius")),
        CiApp(id: "demo-app-oboro", attributes: .init(name: "Oboro", bundleId: "com.yorigami.oboro")),
        CiApp(id: "demo-app-codezero", attributes: .init(name: "Code Zero", bundleId: "com.yorigami.codezero")),
        CiApp(id: "demo-app-kailua", attributes: .init(name: "Kailua", bundleId: "com.yorigami.kailua")),
    ]

    // MARK: - Icon Names

    static let iconNames: [String: String] = [
        "com.yorigami.xenon": "App.Xenon",
        "com.yorigami.amethyst": "App.Amethyst",
        "com.yorigami.dahlia": "App.Dahlia",
        "com.yorigami.sirius": "App.Sirius",
        "com.yorigami.oboro": "App.Oboro",
        "com.yorigami.codezero": "App.CodeZero",
        "com.yorigami.kailua": "App.Kailua",
    ]

    // MARK: - Workflows

    static func workflows(forAppID appID: String) -> [CiWorkflow] {
        switch appID {
        case "demo-app-xenon", "demo-app-amethyst", "demo-app-dahlia",
             "demo-app-sirius", "demo-app-oboro", "demo-app-codezero", "demo-app-kailua":
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
        // Sirius iOS - latest build still running
        case "demo-app-sirius-workflow-ios":
            return siriusIOSBuilds
        case "demo-app-sirius-workflow-macos":
            return siriusMacOSBuilds
        // Oboro iOS - latest build failed
        case "demo-app-oboro-workflow-ios":
            return oboroIOSBuilds
        case "demo-app-oboro-workflow-macos":
            return oboroMacOSBuilds
        // Code Zero iOS - latest build pending
        case "demo-app-codezero-workflow-ios":
            return codeZeroIOSBuilds
        case "demo-app-codezero-workflow-macos":
            return codeZeroMacOSBuilds
        // Kailua - all builds succeeded
        case "demo-app-kailua-workflow-ios":
            return kailuaIOSBuilds
        case "demo-app-kailua-workflow-macos":
            return kailuaMacOSBuilds
        default:
            return []
        }
    }

    static func latestBuildRun(forAppID appID: String) -> CiBuildRun? {
        workflows(forAppID: appID)
            .flatMap { buildRuns(forWorkflowID: $0.id) }
            .max { ($0.attributes.createdDate ?? "") < ($1.attributes.createdDate ?? "") }
    }

    static func branchNames(forWorkflowID workflowID: String) -> [String: String] {
        var result: [String: String] = [:]
        for build in buildRuns(forWorkflowID: workflowID) {
            result[build.id] = "main"
        }
        return result
    }

    // MARK: - Build Actions

    private static var allBuilds: [CiBuildRun] {
        xenonIOSBuilds + xenonMacOSBuilds
            + amethystIOSBuilds + amethystMacOSBuilds
            + dahliaIOSBuilds + dahliaMacOSBuilds
            + siriusIOSBuilds + siriusMacOSBuilds
            + oboroIOSBuilds + oboroMacOSBuilds
            + codeZeroIOSBuilds + codeZeroMacOSBuilds
            + kailuaIOSBuilds + kailuaMacOSBuilds
    }

    static func buildActions(forBuildRunID buildRunID: String) -> [CiBuildAction] {
        // Determine status from build run
        guard let build = allBuilds.first(where: { $0.id == buildRunID }) else {
            return []
        }
        let isFailed = build.attributes.completionStatus == .failed
        let progress = build.attributes.executionProgress ?? .complete
        let actionStatus: CompletionStatus? = progress == .complete ? (isFailed ? .failed : .succeeded) : nil
        return [
            CiBuildAction(
                id: "\(buildRunID)-action-build",
                attributes: .init(
                    name: "Build",
                    actionType: "BUILD",
                    executionProgress: progress,
                    completionStatus: actionStatus,
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
                    executionProgress: progress,
                    completionStatus: actionStatus,
                    startedDate: build.attributes.startedDate,
                    finishedDate: build.attributes.finishedDate,
                    issueCounts: isFailed
                        ? .init(analyzerWarnings: 0, errors: 0, testFailures: 2, warnings: 0)
                        : .init(analyzerWarnings: 0, errors: 0, testFailures: 0, warnings: 0)
                )
            ),
        ]
    }

    // MARK: - Issues

    static func issues(forBuildActionID actionID: String) -> [CiIssue] {
        let buildRunID: String
        let isTestAction: Bool
        if actionID.hasSuffix("-action-build") {
            buildRunID = String(actionID.dropLast("-action-build".count))
            isTestAction = false
        } else if actionID.hasSuffix("-action-test") {
            buildRunID = String(actionID.dropLast("-action-test".count))
            isTestAction = true
        } else {
            return []
        }

        guard let build = allBuilds.first(where: { $0.id == buildRunID }),
              build.attributes.completionStatus == .failed else {
            return []
        }

        if isTestAction {
            return [
                CiIssue(
                    id: "\(actionID)-issue-1",
                    attributes: .init(
                        issueType: .testFailure,
                        message: "testImageCacheEviction(): XCTAssertEqual failed: (\"3\") is not equal to (\"0\")",
                        fileSource: .init(path: "Tests/ImageCacheTests.swift", lineNumber: 87),
                        category: nil
                    )
                ),
                CiIssue(
                    id: "\(actionID)-issue-2",
                    attributes: .init(
                        issueType: .testFailure,
                        message: "testConcurrentAccess(): Asynchronous wait failed: Exceeded timeout of 5 seconds",
                        fileSource: .init(path: "Tests/ImageCacheTests.swift", lineNumber: 132),
                        category: nil
                    )
                ),
            ]
        }
        return [
            CiIssue(
                id: "\(actionID)-issue-1",
                attributes: .init(
                    issueType: .error,
                    message: "Cannot find 'ImageCacheConfiguration' in scope",
                    fileSource: .init(path: "Sources/Caching/ImageCache.swift", lineNumber: 42),
                    category: nil
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

    // MARK: - Sirius Builds (latest running)

    private static let siriusIOSBuilds: [CiBuildRun] = [
        makeBuild(id: "sirius-ios-1", number: 12, status: nil, progress: .running,
                  date: "2026-03-11T09:15:00Z", message: "Add constellation search"),
        makeBuild(id: "sirius-ios-2", number: 11, status: .succeeded,
                  date: "2026-03-10T16:00:00Z", message: "Improve star map rendering"),
        makeBuild(id: "sirius-ios-3", number: 10, status: .succeeded,
                  date: "2026-03-09T10:00:00Z", message: "Add widget support"),
    ]

    private static let siriusMacOSBuilds: [CiBuildRun] = [
        makeBuild(id: "sirius-macos-1", number: 11, status: .succeeded,
                  date: "2026-03-10T16:30:00Z", message: "Improve star map rendering"),
        makeBuild(id: "sirius-macos-2", number: 10, status: .succeeded,
                  date: "2026-03-09T10:30:00Z", message: "Add widget support"),
    ]

    // MARK: - Oboro Builds (latest failed)

    private static let oboroIOSBuilds: [CiBuildRun] = [
        makeBuild(id: "oboro-ios-1", number: 7, status: .failed,
                  date: "2026-03-11T08:40:00Z", message: "Migrate journal entries to SwiftData"),
        makeBuild(id: "oboro-ios-2", number: 6, status: .succeeded,
                  date: "2026-03-10T12:00:00Z", message: "Add moon phase calendar"),
    ]

    private static let oboroMacOSBuilds: [CiBuildRun] = [
        makeBuild(id: "oboro-macos-1", number: 6, status: .succeeded,
                  date: "2026-03-10T12:30:00Z", message: "Add moon phase calendar"),
    ]

    // MARK: - Code Zero Builds (latest pending)

    private static let codeZeroIOSBuilds: [CiBuildRun] = [
        makeBuild(id: "codezero-ios-1", number: 3, status: nil, progress: .pending,
                  date: "2026-03-11T09:30:00Z", message: "Add syntax highlighting themes"),
        makeBuild(id: "codezero-ios-2", number: 2, status: .succeeded,
                  date: "2026-03-10T11:00:00Z", message: "Support external keyboards"),
        makeBuild(id: "codezero-ios-3", number: 1, status: .succeeded,
                  date: "2026-03-09T09:00:00Z", message: "Initial commit"),
    ]

    private static let codeZeroMacOSBuilds: [CiBuildRun] = [
        makeBuild(id: "codezero-macos-1", number: 2, status: .succeeded,
                  date: "2026-03-10T11:30:00Z", message: "Support external keyboards"),
    ]

    // MARK: - Kailua Builds (all succeeded)

    private static let kailuaIOSBuilds: [CiBuildRun] = [
        makeBuild(id: "kailua-ios-1", number: 4, status: .succeeded,
                  date: "2026-03-10T17:00:00Z", message: "Add surf forecast alerts"),
        makeBuild(id: "kailua-ios-2", number: 3, status: .succeeded,
                  date: "2026-03-09T15:00:00Z", message: "Show tide charts"),
    ]

    private static let kailuaMacOSBuilds: [CiBuildRun] = [
        makeBuild(id: "kailua-macos-1", number: 4, status: .succeeded,
                  date: "2026-03-10T17:30:00Z", message: "Add surf forecast alerts"),
    ]

    // MARK: - Helpers

    private static func makeBuild(
        id: String, number: Int, status: CompletionStatus?,
        progress: ExecutionProgress = .complete,
        date: String, message: String
    ) -> CiBuildRun {
        CiBuildRun(
            id: "demo-build-\(id)",
            attributes: .init(
                number: number,
                createdDate: date,
                startedDate: progress == .pending ? nil : date,
                finishedDate: progress == .complete ? date : nil,
                sourceCommit: .init(
                    commitSha: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(40)),
                    message: message,
                    author: .init(displayName: "Demo User")
                ),
                executionProgress: progress,
                completionStatus: status,
                isPullRequestBuild: false
            ),
            relationships: nil
        )
    }
}
