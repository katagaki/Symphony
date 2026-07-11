import SwiftUI

struct BuildActionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let action: CiBuildAction
    @State private var manager: BuildRunManager
    @State private var selectedTab: Tab
    @State private var didLoadIssues = false
    @State private var didLoadLog = false

    enum Tab {
        case issues
        case log
    }

    init(action: CiBuildAction, api: AppStoreConnectAPI) {
        self.action = action
        _manager = State(initialValue: BuildRunManager(api: api))
        _selectedTab = State(initialValue: Self.hasIssues(action) ? .issues : .log)
    }

    init(action: CiBuildAction, demoMode: Bool) {
        self.action = action
        _manager = State(initialValue: BuildRunManager(demoMode: true))
        _selectedTab = State(initialValue: Self.hasIssues(action) ? .issues : .log)
    }

    private static func hasIssues(_ action: CiBuildAction) -> Bool {
        guard let counts = action.attributes.issueCounts else { return false }
        return (counts.errors ?? 0) + (counts.warnings ?? 0)
            + (counts.testFailures ?? 0) + (counts.analyzerWarnings ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .issues:
                    issuesContent
                case .log:
                    logContent
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Build.Action.Section", selection: $selectedTab) {
                    Text("Build.Action.Issues").tag(Tab.issues)
                    Text("Build.Action.Log").tag(Tab.log)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle(action.attributes.name ?? String(localized: "Build.Log.Title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task(id: selectedTab) {
                switch selectedTab {
                case .issues:
                    if !didLoadIssues {
                        didLoadIssues = true
                        await manager.loadIssues(forActionID: action.id)
                    }
                case .log:
                    if !didLoadLog {
                        didLoadLog = true
                        await manager.loadLog(forActionID: action.id)
                    }
                }
            }
        }
    }

    // MARK: - Issues

    @ViewBuilder
    private var issuesContent: some View {
        if manager.isLoadingIssues {
            VStack(spacing: 16) {
                ProgressView()
                Text("Build.Issues.Loading")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if manager.issues.isEmpty {
            ContentUnavailableView(
                "Build.Issues.NoIssues",
                systemImage: "checkmark.circle",
                description: Text("Build.Issues.NoIssuesDescription")
            )
        } else {
            List(manager.issues) { issue in
                IssueRowView(issue: issue)
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Log

    @ViewBuilder
    private var logContent: some View {
        if manager.isLoadingLog {
            VStack(spacing: 16) {
                ProgressView()
                Text("Build.Log.Loading")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let logText = manager.logText {
            ScrollView {
                Text(logText)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
        } else {
            ContentUnavailableView(
                "Build.Log.NoLogs",
                systemImage: "doc.text",
                description: Text("Build.Log.NoLogsDescription")
            )
        }
    }
}

private struct IssueRowView: View {
    let issue: CiIssue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(iconColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(typeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let message = issue.attributes.message {
                    Text(message)
                        .font(.subheadline)
                }
                if let path = issue.attributes.fileSource?.path {
                    Text(fileLocation(path: path, line: issue.attributes.fileSource?.lineNumber))
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func fileLocation(path: String, line: Int?) -> String {
        if let line {
            return "\(path):\(line)"
        }
        return path
    }

    private var iconName: String {
        switch issue.attributes.issueType {
        case .error: "xmark.circle.fill"
        case .testFailure: "xmark.diamond.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .analyzerWarning: "magnifyingglass.circle.fill"
        case nil: "questionmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch issue.attributes.issueType {
        case .error, .testFailure: .red
        case .warning: .yellow
        case .analyzerWarning: .purple
        case nil: Color.secondary
        }
    }

    private var typeLabel: LocalizedStringKey {
        switch issue.attributes.issueType {
        case .error: "Build.Issues.Type.Error"
        case .testFailure: "Build.Issues.Type.TestFailure"
        case .warning: "Build.Issues.Type.Warning"
        case .analyzerWarning: "Build.Issues.Type.AnalyzerWarning"
        case nil: "Build.Issues.Type.Unknown"
        }
    }
}
