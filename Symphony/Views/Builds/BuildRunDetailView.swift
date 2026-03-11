import SwiftUI

struct BuildRunDetailView: View {
    @Environment(AuthenticationManager.self) private var authManager
    let buildRun: CiBuildRun
    @State private var manager: BuildRunManager?
    @State private var selectedAction: CiBuildAction?

    var body: some View {
        Group {
            if let manager {
                if manager.isLoading && manager.actions.isEmpty {
                    ProgressView("Build.Detail.Loading")
                } else {
                    List {
                        Section {
                            VStack(spacing: 8) {
                                let badge = BuildStatusBadge(
                                    progress: manager.buildRun?.attributes.executionProgress,
                                    status: manager.buildRun?.attributes.completionStatus
                                )
                                Image(systemName: badge.iconName)
                                    .font(.system(size: 56))
                                    .symbolRenderingMode(.multicolor)
                                    .foregroundStyle(badge.iconColor)
                                Text(badge.labelText)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)

                        Section {
                            if let created = manager.buildRun?.attributes.createdDate {
                                LabeledContent("Build.Detail.Created", value: formatDate(created))
                            }
                            if let started = manager.buildRun?.attributes.startedDate {
                                LabeledContent("Build.Detail.Started", value: formatDate(started))
                            }
                            if let finished = manager.buildRun?.attributes.finishedDate {
                                LabeledContent("Build.Detail.Finished", value: formatDate(finished))
                            }
                        }

                        if let commit = manager.buildRun?.attributes.sourceCommit {
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

                        if !manager.actions.isEmpty {
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
                                                    .foregroundStyle(.primary)
                                                if let issues = action.attributes.issueCounts {
                                                    HStack(spacing: 12) {
                                                        if let errors = issues.errors, errors > 0 {
                                                            Label("\(errors)", systemImage: "xmark.circle.fill")
                                                                .foregroundStyle(.red)
                                                        }
                                                        if let warnings = issues.warnings, warnings > 0 {
                                                            Label("\(warnings)", systemImage: "exclamationmark.triangle.fill")
                                                                .foregroundStyle(.orange)
                                                        }
                                                        if let failures = issues.testFailures, failures > 0 {
                                                            Label("\(failures)", systemImage: "xmark.diamond.fill")
                                                                .foregroundStyle(.red)
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
                                }
                            }
                        }
                    }
                    .refreshable {
                        await manager.loadBuildRun(id: buildRun.id)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Build #\(buildRun.attributes.number ?? 0)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAction) { action in
            if let api = authManager.api {
                BuildLogView(action: action, api: api)
            }
        }
        .task {
            guard let api = authManager.api else { return }
            if manager == nil {
                let m = BuildRunManager(api: api)
                manager = m
                await m.loadBuildRun(id: buildRun.id)

                // Poll if build is still in progress
                if buildRun.attributes.executionProgress != .complete {
                    await m.pollBuildStatus(id: buildRun.id)
                }
            }
        }
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
