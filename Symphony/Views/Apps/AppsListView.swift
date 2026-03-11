import SwiftUI

enum AppSortOrder: CaseIterable {
    case name
    case bundleId

    var localizedName: String {
        switch self {
        case .name: return String(localized: "Apps.Sort.Name")
        case .bundleId: return String(localized: "Apps.Sort.BundleID")
        }
    }
}

struct AppsListView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var appsManager: AppsManager?
    @State private var sortOrder: AppSortOrder = .name
    @State private var forceRefreshIcons = false
    @Environment(\.openURL) private var openURL

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
                    ProgressView("Apps.Loading")
                } else if let error = manager.error, manager.apps.isEmpty {
                    ContentUnavailableView {
                        Label("Apps.FailedToLoad", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Shared.Retry") {
                            Task { await manager.loadApps() }
                        }
                    }
                } else if manager.apps.isEmpty {
                    ContentUnavailableView(
                        "Apps.NoApps",
                        systemImage: "app.dashed",
                        description: Text("Apps.NoAppsDescription")
                    )
                } else {
                    List(sortedApps) { app in
                        NavigationLink(value: app) {
                            AppRowView(app: app, forceRefreshIcons: forceRefreshIcons)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        forceRefreshIcons = true
                        await manager.loadApps()
                        forceRefreshIcons = false
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Apps.Title")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Apps.SortBy", selection: $sortOrder) {
                        ForEach(AppSortOrder.allCases, id: \.self) { order in
                            Text(order.localizedName)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            ToolbarSpacer(.fixed)
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        authManager.signOut()
                    } label: {
                        Label("Shared.SignOut", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Divider()
                    Button {
                        openURL(URL(string: "https://github.com/katagaki/Symphony")!)
                    } label: {
                        Label("Shared.SourceCode", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } label: {
                    Image(systemName: "ellipsis")
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
