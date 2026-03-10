import SwiftUI

struct BuildLogView: View {
    @Environment(\.dismiss) private var dismiss
    let action: CiBuildAction
    @State private var manager: BuildRunManager

    init(action: CiBuildAction, api: AppStoreConnectAPI) {
        self.action = action
        _manager = State(initialValue: BuildRunManager(api: api))
    }

    var body: some View {
        NavigationStack {
            Group {
                if manager.isLoadingLog {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading logs...")
                            .foregroundStyle(.secondary)
                    }
                } else if let logText = manager.logText {
                    ScrollView {
                        Text(logText)
                            .font(.system(.caption2, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }
                } else {
                    ContentUnavailableView(
                        "No Logs",
                        systemImage: "doc.text",
                        description: Text("No log content available for this action.")
                    )
                }
            }
            .navigationTitle(action.attributes.name ?? "Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await manager.loadLog(forActionID: action.id)
            }
        }
    }
}
