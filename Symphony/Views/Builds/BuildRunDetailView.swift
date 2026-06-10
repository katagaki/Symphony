import SwiftUI

struct BuildRunDetailView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.openURL) private var openURL
    let app: CiApp
    let buildRun: CiBuildRun
    @State private var manager: BuildRunManager?
    @State private var selectedAction: CiBuildAction?
    @State private var showTeamIDSheet = false

    private var currentBuildRun: CiBuildRun? {
        manager?.buildRun ?? buildRun
    }

    private var isBuildInProgress: Bool {
        currentBuildRun?.attributes.executionProgress == .pending
            || currentBuildRun?.attributes.executionProgress == .running
    }

    var body: some View {
        Group {
            if let manager {
                List {
                    Section {
                        VStack(spacing: 4) {
                            let badge = BuildStatusBadge(
                                progress: currentBuildRun?.attributes.executionProgress,
                                status: currentBuildRun?.attributes.completionStatus
                            )
                            Image(systemName: badge.iconName)
                                .font(.system(size: 56))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(badge.iconColor)
                            Text(badge.labelText)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                    .listSectionSpacing(.zero)

                    Section {
                        if let created = currentBuildRun?.attributes.createdDate {
                            LabeledContent("Build.Detail.Created", value: formatDate(created))
                        }
                        if let started = currentBuildRun?.attributes.startedDate {
                            LabeledContent("Build.Detail.Started", value: formatDate(started))
                        }
                        if let finished = currentBuildRun?.attributes.finishedDate {
                            LabeledContent("Build.Detail.Finished", value: formatDate(finished))
                        }
                        // There is no official API to cancel a build, so builds are
                        // stopped from the App Store Connect website instead.
                        if isBuildInProgress && !authManager.isDemoMode {
                            Button(role: .destructive) {
                                if authManager.selectedTeamID != nil {
                                    openStopBuildPage()
                                } else {
                                    showTeamIDSheet = true
                                }
                            } label: {
                                Label("Build.Detail.StopBuildWeb", systemImage: "stop.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        }
                    }

                    if let commit = currentBuildRun?.attributes.sourceCommit {
                        Section("Build.Source") {
                            if let sha = commit.commitSha {
                                LabeledContent("Build.Source.Commit", value: String(sha.prefix(7)))
                            }
                            if let author = commit.author?.displayName {
                                LabeledContent("Build.Source.Author", value: author)
                            }
                            if let message = commit.message {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if manager.isLoading && manager.actions.isEmpty {
                        Section("Build.Actions") {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    } else if !manager.actions.isEmpty {
                        Section("Build.Actions") {
                            ForEach(manager.actions.sorted {
                                ($0.attributes.startedDate ?? "") < ($1.attributes.startedDate ?? "")
                            }) { action in
                                Button {
                                    selectedAction = action
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(action.attributes.name ?? action.attributes.actionType ?? String(localized: "Build.Actions.Action"))
                                                .font(.headline)
                                            if let issues = action.attributes.issueCounts {
                                                HStack(spacing: 12) {
                                                    if let errors = issues.errors, errors > 0 {
                                                        Label("\(errors)", systemImage: "xmark.circle.fill")
                                                            .symbolRenderingMode(.multicolor)
                                                    }
                                                    if let warnings = issues.warnings, warnings > 0 {
                                                        Label("\(warnings)", systemImage: "exclamationmark.triangle.fill")
                                                            .symbolRenderingMode(.multicolor)
                                                    }
                                                    if let failures = issues.testFailures, failures > 0 {
                                                        Label("\(failures)", systemImage: "xmark.diamond.fill")
                                                            .symbolRenderingMode(.multicolor)
                                                    }
                                                }
                                                .font(.caption)
                                            }
                                        }
                                        Spacer()
                                        BuildStatusBadge(
                                            progress: action.attributes.executionProgress,
                                            status: action.attributes.completionStatus
                                        )
                                    }
                                }
                                .tint(.primary)
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                            }
                        }
                    }
                }
                .contentMargins(.top, 0, for: .scrollContent)
                .refreshable {
                    await manager.refreshBuildRun(id: buildRun.id)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Group {
                            if manager.isRefreshing {
                                ProgressView()
                            } else {
                                EmptyView()
                            }
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Build #\(buildRun.attributes.number ?? 0)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAction) { action in
            if authManager.isDemoMode {
                BuildLogView(action: action, demoMode: true)
                    .interactiveDismissDisabled()
            } else if let api = authManager.api {
                BuildLogView(action: action, api: api)
                    .interactiveDismissDisabled()
            }
        }
        .sheet(isPresented: $showTeamIDSheet) {
            TeamIDView { _ in
                openStopBuildPage()
            }
        }
        .task {
            if manager == nil {
                let m: BuildRunManager
                if authManager.isDemoMode {
                    m = BuildRunManager(demoMode: true)
                } else {
                    guard let api = authManager.api else { return }
                    m = BuildRunManager(api: api)
                }
                manager = m
                await m.loadBuildRun(id: buildRun.id, initial: buildRun)

                // Poll if build is still in progress
                if buildRun.attributes.executionProgress != .complete {
                    await m.pollBuildStatus(id: buildRun.id)
                }
            }
        }
    }

    private func openStopBuildPage() {
        guard let teamID = authManager.selectedTeamID,
              let url = URL(string: "https://appstoreconnect.apple.com/teams/\(teamID)/apps/\(app.id)/ci/builds/\(buildRun.id)/summary") else {
            return
        }
        openURL(url)
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: isoString) else {
                return isoString
            }
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
