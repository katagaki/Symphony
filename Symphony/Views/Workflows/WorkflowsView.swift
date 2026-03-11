import SwiftUI

struct WorkflowsView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Namespace private var namespace
    let app: CiApp
    @State private var manager: WorkflowsManager?
    @State private var selectedWorkflow: CiWorkflow?
    @State private var selectedWorkflowForDetail: CiWorkflow?
    @State private var forceRefreshIcons = false
    @State private var expandedWorkflows: Set<String> = []

    private let initialBuildCount = 5

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
                                AppIconView(bundleId: app.attributes.bundleId, forceRefresh: forceRefreshIcons)
                                    .frame(width: 128, height: 128)
                                VStack(spacing: 4) {
                                    Text(app.attributes.name)
                                        .font(.title3)
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
                    .contentMargins(.top, 0, for: .scrollContent)
                    .refreshable {
                        forceRefreshIcons = true
                        await manager.loadWorkflows()
                        forceRefreshIcons = false
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
                    .interactiveDismissDisabled()
                    .navigationTransition(.zoom(sourceID: "startBuild-\(workflow.id)", in: namespace))
            }
        }
        .sheet(item: $selectedWorkflowForDetail) { workflow in
            if let api = authManager.api {
                WorkflowDetailView(workflow: workflow, api: api)
                    .navigationTransition(.zoom(sourceID: "viewWorkflow-\(workflow.id)", in: namespace))
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
                let isExpanded = expandedWorkflows.contains(workflow.id)
                let visibleBuilds = isExpanded ? builds : Array(builds.prefix(initialBuildCount))
                ForEach(visibleBuilds) { buildRun in
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
                if !isExpanded && builds.count > initialBuildCount {
                    Button {
                        withAnimation {
                            _ = expandedWorkflows.insert(workflow.id)
                        }
                    } label: {
                        Text("Workflows.ShowMore \(builds.count - initialBuildCount)")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        } header: {
            HStack {
                Text(workflow.attributes.name)
                Spacer()
                Button {
                    selectedWorkflowForDetail = workflow
                } label: {
                    Image(systemName: "info.circle")
                        .imageScale(.large)
                }
                .matchedTransitionSource(id: "viewWorkflow-\(workflow.id)", in: namespace)
                Button {
                    selectedWorkflow = workflow
                } label: {
                    Image(systemName: "play.fill")
                        .imageScale(.large)
                }
                .matchedTransitionSource(id: "startBuild-\(workflow.id)", in: namespace)
            }
        }
    }
}
