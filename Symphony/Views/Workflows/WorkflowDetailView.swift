import SwiftUI

struct WorkflowDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let workflow: CiWorkflow
    let api: AppStoreConnectAPI
    @State private var detailedWorkflow: CiWorkflow?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Workflow.Detail.Loading")
                } else if let error {
                    ContentUnavailableView {
                        Label("Workflows.FailedToLoad", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Shared.Retry") {
                            Task { await loadWorkflow() }
                        }
                    }
                } else {
                    let wf = detailedWorkflow ?? workflow
                    List {
                        Section("Workflow.Detail.General") {
                            LabeledContent("Workflow.Detail.Name", value: wf.attributes.name)
                            if let description = wf.attributes.description, !description.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Workflow.Detail.Description")
                                        .foregroundStyle(.secondary)
                                    Text(description)
                                }
                            }
                        }

                        Section("Workflow.Detail.Status") {
                            LabeledContent("Workflow.Detail.Enabled") {
                                if wf.attributes.isEnabled == true {
                                    Label("Workflow.Detail.Yes", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .labelStyle(.iconOnly)
                                } else {
                                    Label("Workflow.Detail.No", systemImage: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .labelStyle(.iconOnly)
                                }
                            }
                            if wf.attributes.isLockedForEditing == true {
                                LabeledContent("Workflow.Detail.Locked") {
                                    Label("Workflow.Detail.Yes", systemImage: "lock.fill")
                                        .foregroundStyle(.orange)
                                        .labelStyle(.iconOnly)
                                }
                            }
                        }

                        if let lastModified = wf.attributes.lastModifiedDate {
                            Section("Workflow.Detail.Activity") {
                                LabeledContent("Workflow.Detail.LastModified") {
                                    Text(Self.formatDate(lastModified))
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
            }
            .navigationTitle("Workflow.Detail.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .task {
            await loadWorkflow()
        }
    }

    private func loadWorkflow() async {
        isLoading = true
        error = nil
        do {
            detailedWorkflow = try await api.getWorkflow(id: workflow.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private static func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
