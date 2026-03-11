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
                        Section {
                            HStack(spacing: 12) {
                                AppIconView(bundleId: app.attributes.bundleId)
                                    .frame(width: 64, height: 64)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.attributes.name)
                                        .font(.headline)
                                    Text(app.attributes.bundleId)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                            .listRowBackground(Color.clear)
                        }
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
        .navigationTitle(app.attributes.name)
        .navigationBarTitleDisplayMode(.inline)
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
                Text("No builds yet")
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
                                Label("Cancel", systemImage: "xmark.circle")
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
                    showStartBuild = true
                } label: {
                    Label("Start Build", systemImage: "play.fill")
                        .font(.caption)
                }
            }
        }
    }
}
