import SwiftUI

struct WorkflowsView: View {
    @Environment(AuthenticationManager.self) private var authManager
    let app: CiApp
    @State private var manager: WorkflowsManager?
    @State private var selectedWorkflow: CiWorkflow?

    var body: some View {
        Group {
            if let manager {
                if manager.isLoading && manager.workflows.isEmpty {
                    ProgressView("Workflows.Loading")
                } else if let error = manager.error, manager.workflows.isEmpty {
                    ContentUnavailableView {
                        Label("Workflows.FailedToLoad", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Shared.Retry") {
                            Task { await manager.loadWorkflows() }
                        }
                    }
                } else if manager.workflows.isEmpty {
                    ContentUnavailableView(
                        "Workflows.NoWorkflows",
                        systemImage: "hammer.fill",
                        description: Text("Workflows.NoWorkflowsDescription")
                    )
                } else {
                    List {
                        Section {
                            VStack(spacing: 8) {
                                AppIconView(bundleId: app.attributes.bundleId)
                                    .frame(width: 64, height: 64)
                                VStack(spacing: 4) {
                                    Text(app.attributes.name)
                                        .font(.headline)
                                    Text(app.attributes.bundleId)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                            .listRowBackground(Color.clear)
                        }
                        .listSectionSpacing(0)
                        ForEach(manager.workflows) { workflow in
                            workflowSection(workflow: workflow, manager: manager)
                        }
                    }
                    .refreshable {
                        await manager.loadWorkflows()
                    }
                    .overlay(alignment: .topTrailing) {
                        if manager.isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                                .padding(8)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWorkflow) { workflow in
            if let api = authManager.api {
                StartBuildView(workflow: workflow, api: api)
            }
        }
        .task {
            guard let api = authManager.api else { return }
            if manager == nil {
                let m = WorkflowsManager(api: api, app: app)
                manager = m
                await m.loadWorkflows()
                m.startAutoRefresh()
            }
        }
        .onDisappear {
            manager?.stopAutoRefresh()
        }
    }

    @ViewBuilder
    private func workflowSection(workflow: CiWorkflow, manager: WorkflowsManager) -> some View {
        Section {
            let builds = (manager.buildRunsByWorkflow[workflow.id] ?? []).sorted {
                    ($0.attributes.number ?? 0) > ($1.attributes.number ?? 0)
                }
            if builds.isEmpty {
                Text("Workflows.NoBuildsYet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(builds) { buildRun in
                    NavigationLink(value: buildRun) {
                        HStack {
                            BuildStatusIcon(
                                progress: buildRun.attributes.executionProgress,
                                status: buildRun.attributes.completionStatus
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Build #\(buildRun.attributes.number ?? 0)")
                                    .font(.headline)
                                if let branchName = manager.branchNamesByBuildRun[buildRun.id] {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.triangle.branch")
                                        Text(branchName)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                if let commit = buildRun.attributes.sourceCommit,
                                   let message = commit.message {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if buildRun.attributes.executionProgress == .pending
                            || buildRun.attributes.executionProgress == .running {
                            Button(role: .destructive) {
                                Task {
                                    await manager.cancelBuildRun(id: buildRun.id)
                                }
                            } label: {
                                Label("Shared.Cancel", systemImage: "xmark.circle")
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text(workflow.attributes.name)
                Spacer()
                Button {
                    selectedWorkflow = workflow
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "play.fill")
                        Text("Build.Start.Title")
                    }
                    .font(.caption)
                }
            }
        }
    }
}
