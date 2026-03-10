import SwiftUI

struct AppsListView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var appsManager: AppsManager?

    var body: some View {
        Group {
            if let manager = appsManager {
                if manager.isLoading && manager.apps.isEmpty {
                    ProgressView("Loading apps...")
                } else if let error = manager.error, manager.apps.isEmpty {
                    ContentUnavailableView {
                        Label("Failed to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await manager.loadApps() }
                        }
                    }
                } else if manager.apps.isEmpty {
                    ContentUnavailableView(
                        "No Apps",
                        systemImage: "app.dashed",
                        description: Text("No apps found in your App Store Connect account.")
                    )
                } else {
                    List(manager.apps) { app in
                        NavigationLink(value: app) {
                            AppRowView(app: app)
                        }
                    }
                    .refreshable {
                        await manager.loadApps()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Apps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task {
            guard let api = authManager.api else { return }
            if appsManager == nil {
                let manager = AppsManager(api: api)
                appsManager = manager
                await manager.loadApps()
            }
        }
    }
}
