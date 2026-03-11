import SwiftUI

struct StartBuildView: View {
    @Environment(\.dismiss) private var dismiss
    let workflow: CiWorkflow
    @State private var manager: BuildRunManager
    @State private var selectedRefID: String?
    @State private var didStartBuild = false

    init(workflow: CiWorkflow, api: AppStoreConnectAPI) {
        self.workflow = workflow
        _manager = State(initialValue: BuildRunManager(api: api))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Build.Start.Workflow", value: workflow.attributes.name)
                }

                Section("Build.Start.BranchOrTag") {
                    if manager.gitReferences.isEmpty && manager.error == nil {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Build.Start.LoadingRefs")
                                .foregroundStyle(.secondary)
                        }
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
                        guard let refID = selectedRefID else { return }
                        Task {
                            await manager.startBuild(
                                workflowID: workflow.id,
                                gitReferenceID: refID
                            )
                            if manager.error == nil {
                                didStartBuild = true
                                try? await Task.sleep(for: .seconds(1.5))
                                dismiss()
                            }
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
                    .disabled(selectedRefID == nil || manager.isStartingBuild || didStartBuild)
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
                await manager.loadGitReferences(workflowID: workflow.id)
            }
        }
        .presentationDetents([.medium])
    }
}
