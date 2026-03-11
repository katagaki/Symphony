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
                        Text("Build.Log.Loading")
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
                        "Build.Log.NoLogs",
                        systemImage: "doc.text",
                        description: Text("Build.Log.NoLogsDescription")
                    )
                }
            }
            .navigationTitle(action.attributes.name ?? String(localized: "Build.Log.Title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task {
                await manager.loadLog(forActionID: action.id)
            }
        }
    }
}
