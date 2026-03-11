import SwiftUI

enum AppSortOrder: String, CaseIterable {
    case name = "Name"
    case bundleId = "Bundle ID"
}

struct AppsListView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var appsManager: AppsManager?
    @State private var sortOrder: AppSortOrder = .name

    private var sortedApps: [CiApp] {
        guard let apps = appsManager?.apps else { return [] }
        switch sortOrder {
        case .name:
            return apps.sorted { $0.attributes.name.localizedCaseInsensitiveCompare($1.attributes.name) == .orderedAscending }
        case .bundleId:
            return apps.sorted { $0.attributes.bundleId.localizedCaseInsensitiveCompare($1.attributes.bundleId) == .orderedAscending }
        }
    }

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
                    List(sortedApps) { app in
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
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Sort By", selection: $sortOrder) {
                        ForEach(AppSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
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
