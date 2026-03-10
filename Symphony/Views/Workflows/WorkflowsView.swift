import SwiftUI

struct WorkflowsView: View {
    @Environment(AuthenticationManager.self) private var authManager
    let app: CiApp
    @State private var manager: WorkflowsManager?
    @State private var showStartBuild = false
    @State private var selectedWorkflow: CiWorkflow?

    var body: some View {
        Group {
            if let manager {
                if manager.isLoading && manager.workflows.isEmpty {
                    ProgressView("Loading workflows...")
                } else if let error = manager.error, manager.workflows.isEmpty {
                    ContentUnavailableView {
                        Label("Failed to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await manager.loadWorkflows() }
                        }
                    }
                } else if manager.workflows.isEmpty {
                    ContentUnavailableView(
                        "No Workflows",
                        systemImage: "hammer.fill",
                        description: Text("No Xcode Cloud workflows found for this app.")
                    )
                } else {
                    List {
                        ForEach(manager.workflows) { workflow in
                            WorkflowRowView(
                                workflow: workflow,
                                latestBuild: manager.latestBuildRuns[workflow.id]
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedWorkflow = workflow
                                showStartBuild = true
                            }
                            .contextMenu {
                                if let buildRun = manager.latestBuildRuns[workflow.id] {
                                    NavigationLink(value: buildRun) {
                                        Label("View Latest Build", systemImage: "eye")
                                    }
                                }
                                Button {
                                    selectedWorkflow = workflow
                                    showStartBuild = true
                                } label: {
                                    Label("Start Build", systemImage: "play.fill")
                                }
                            }
                        }

                        if !manager.latestBuildRuns.isEmpty {
                            Section("Recent Builds") {
                                ForEach(
                                    Array(manager.latestBuildRuns.values)
                                        .sorted(by: {
                                            ($0.attributes.createdDate ?? "") > ($1.attributes.createdDate ?? "")
                                        }),
                                    id: \.id
                                ) { buildRun in
                                    NavigationLink(value: buildRun) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Build #\(buildRun.attributes.number ?? 0)")
                                                    .font(.headline)
                                                if let commit = buildRun.attributes.sourceCommit,
                                                   let message = commit.message {
                                                    Text(message)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                            BuildStatusBadge(
                                                progress: buildRun.attributes.executionProgress,
                                                status: buildRun.attributes.completionStatus
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await manager.loadWorkflows()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(app.attributes.name)
        .sheet(isPresented: $showStartBuild) {
            if let workflow = selectedWorkflow, let api = authManager.api {
                StartBuildView(workflow: workflow, api: api)
            }
        }
        .task {
            guard let api = authManager.api else { return }
            if manager == nil {
                let m = WorkflowsManager(api: api, app: app)
                manager = m
                await m.loadWorkflows()
            }
        }
    }
}
