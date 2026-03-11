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
    @State private var searchText = ""
    @State private var forceRefreshIcons = false
    @Environment(\.openURL) private var openURL

    private var filteredAndSortedApps: [CiApp] {
        guard let apps = appsManager?.apps else { return [] }
        let filtered = searchText.isEmpty ? apps : apps.filter {
            $0.attributes.name.localizedCaseInsensitiveContains(searchText) ||
            $0.attributes.bundleId.localizedCaseInsensitiveContains(searchText)
        }
        switch sortOrder {
        case .name:
            return filtered.sorted { $0.attributes.name.localizedCaseInsensitiveCompare($1.attributes.name) == .orderedAscending }
        case .bundleId:
            return filtered.sorted { $0.attributes.bundleId.localizedCaseInsensitiveCompare($1.attributes.bundleId) == .orderedAscending }
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
                    List(filteredAndSortedApps) { app in
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
        .searchable(text: $searchText, prompt: Text("Apps.SearchPrompt"))
        .animation(.smooth.speed(2.0), value: searchText)
        .navigationTitle("Apps.Title")
        .toolbar {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(.fixed, placement: .bottomBar)
            ToolbarItemGroup(placement: .bottomBar) {
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
            ToolbarItemGroup(placement: .topBarTrailing) {
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
            if appsManager == nil {
                let manager: AppsManager
                if authManager.isDemoMode {
                    manager = AppsManager(demoMode: true)
                } else {
                    guard let api = authManager.api else { return }
                    manager = AppsManager(api: api)
                }
                appsManager = manager
                await manager.loadApps()
            }
        }
    }
}
