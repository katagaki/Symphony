import SwiftUI

struct StartBuildView: View {
    @Environment(\.dismiss) private var dismiss
    let workflow: CiWorkflow
    @State private var manager: BuildRunManager
    @State private var sourceType: BuildSourceType = .branchOrTag
    @State private var selectedRefID: String?
    @State private var selectedPullRequestID: String?
    @State private var didStartBuild = false

    enum BuildSourceType {
        case branchOrTag
        case pullRequest
    }

    init(workflow: CiWorkflow, api: AppStoreConnectAPI) {
        self.workflow = workflow
        _manager = State(initialValue: BuildRunManager(api: api))
    }

    private var canStartBuild: Bool {
        switch sourceType {
        case .branchOrTag: selectedRefID != nil
        case .pullRequest: selectedPullRequestID != nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Build.Start.Workflow", value: workflow.attributes.name)
                    Picker("Build.Start.Source", selection: $sourceType) {
                        Text("Build.Start.Source.BranchOrTag").tag(BuildSourceType.branchOrTag)
                        Text("Build.Start.Source.PullRequest").tag(BuildSourceType.pullRequest)
                    }
                    .pickerStyle(.segmented)
                }

                switch sourceType {
                case .branchOrTag:
                    branchOrTagSection
                case .pullRequest:
                    pullRequestSection
                }

                if let error = manager.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if didStartBuild {
                    Section {
                        Label("Build.Start.Success", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Button {
                        Task {
                            await startBuild()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if manager.isStartingBuild {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Build.Start.Starting")
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                    Text("Build.Start.Title")
                                }
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canStartBuild || manager.isStartingBuild || didStartBuild)
                }
            }
            .navigationTitle("Build.Start.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task {
                await manager.loadBuildSources(workflowID: workflow.id)
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var branchOrTagSection: some View {
        Section("Build.Start.BranchOrTag") {
            if manager.isLoadingSources || (manager.gitReferences.isEmpty && manager.error == nil) {
                loadingRow("Build.Start.LoadingRefs")
            } else {
                Picker("Build.Start.SelectReference", selection: $selectedRefID) {
                    Text("Build.Start.SelectPlaceholder")
                        .tag(String?.none)

                    let branches = manager.gitReferences.filter {
                        $0.attributes.kind == .branch
                    }
                    let tags = manager.gitReferences.filter {
                        $0.attributes.kind == .tag
                    }

                    if !branches.isEmpty {
                        Section("Build.Start.Branches") {
                            ForEach(branches) { ref in
                                Label(ref.attributes.name, systemImage: "arrow.triangle.branch")
                                    .tag(Optional(ref.id))
                            }
                        }
                    }

                    if !tags.isEmpty {
                        Section("Build.Start.Tags") {
                            ForEach(tags) { ref in
                                Label(ref.attributes.name, systemImage: "tag")
                                    .tag(Optional(ref.id))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pullRequestSection: some View {
        Section("Build.Start.Source.PullRequest") {
            if manager.isLoadingSources {
                loadingRow("Build.Start.LoadingPullRequests")
            } else if manager.pullRequests.isEmpty {
                Text("Build.Start.NoPullRequests")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Build.Start.SelectPullRequest", selection: $selectedPullRequestID) {
                    Text("Build.Start.SelectPullRequestPlaceholder")
                        .tag(String?.none)

                    ForEach(manager.pullRequests) { pullRequest in
                        Label(pullRequestLabel(pullRequest), systemImage: "arrow.triangle.pull")
                            .tag(Optional(pullRequest.id))
                    }
                }
            }
        }
    }

    private func loadingRow(_ text: LocalizedStringKey) -> some View {
        HStack {
            ProgressView()
                .padding(.trailing, 8)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }

    private func pullRequestLabel(_ pullRequest: ScmPullRequest) -> String {
        let title = pullRequest.attributes.title ?? pullRequest.attributes.sourceBranchName ?? pullRequest.id
        if let number = pullRequest.attributes.number {
            return "#\(number) \(title)"
        }
        return title
    }

    private func startBuild() async {
        switch sourceType {
        case .branchOrTag:
            guard let refID = selectedRefID else { return }
            await manager.startBuild(workflowID: workflow.id, gitReferenceID: refID)
        case .pullRequest:
            guard let pullRequestID = selectedPullRequestID else { return }
            await manager.startBuild(workflowID: workflow.id, pullRequestID: pullRequestID)
        }
        if manager.error == nil {
            didStartBuild = true
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
    }
}
