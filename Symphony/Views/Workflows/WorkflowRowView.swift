import SwiftUI

struct WorkflowRowView: View {
    let workflow: CiWorkflow
    let latestBuild: CiBuildRun?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workflow.attributes.name)
                    .font(.headline)
                if let build = latestBuild {
                    Text("Build #\(build.attributes.number ?? 0)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Workflows.NoBuildsYet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let build = latestBuild {
                BuildStatusBadge(
                    progress: build.attributes.executionProgress,
                    status: build.attributes.completionStatus
                )
            }
        }
        .padding(.vertical, 2)
    }
}
