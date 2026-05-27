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

enum AppsViewMode: String, CaseIterable {
    case list
    case grid

    var localizedName: String {
        switch self {
        case .list: return String(localized: "Apps.View.List")
        case .grid: return String(localized: "Apps.View.Grid")
        }
    }

    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

struct AppsListView: View {
    let namespace: Namespace.ID
    @Environment(AuthenticationManager.self) private var authManager
    @State private var appsManager: AppsManager?
    @State private var sortOrder: AppSortOrder = .name
    @State private var searchText = ""
    @State private var forceRefreshIcons = false
    @State private var showAccounts = false
    @AppStorage("appsViewMode") private var viewMode: AppsViewMode = .list
    @Environment(\.openURL) private var openURL

    private var accountTaskID: String {
        authManager.isDemoMode ? "demo" : (authManager.selectedAccountID?.uuidString ?? "none")
    }

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
                    switch viewMode {
                    case .list:
                        appsList(manager: manager)
                    case .grid:
                        appsGrid(manager: manager)
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
                    Picker("Apps.ViewAs", selection: $viewMode) {
                        ForEach(AppsViewMode.allCases, id: \.self) { mode in
                            Label(mode.localizedName, systemImage: mode.systemImage)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Button {
                        showAccounts = true
                    } label: {
                        Label("Accounts.Title", systemImage: "person.crop.circle")
                    }
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
        .sheet(isPresented: $showAccounts) {
            AccountsView()
        }
        .task(id: accountTaskID) {
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

    private func appsList(manager: AppsManager) -> some View {
        List(filteredAndSortedApps) { app in
            NavigationLink(value: app) {
                AppRowView(app: app, forceRefreshIcons: forceRefreshIcons)
            }
            .matchedTransitionSource(id: app.id, in: namespace)
        }
        .listStyle(.plain)
        .refreshable {
            forceRefreshIcons = true
            await manager.loadApps()
            forceRefreshIcons = false
        }
    }

    private func appsGrid(manager: AppsManager) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 16)],
                spacing: 16
            ) {
                ForEach(filteredAndSortedApps) { app in
                    NavigationLink(value: app) {
                        VStack(spacing: 8) {
                            AppIconView(bundleId: app.attributes.bundleId, forceRefresh: forceRefreshIcons)
                                .frame(width: 80, height: 80)
                            Text(app.attributes.name)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: app.id, in: namespace)
                }
            }
            .padding()
        }
        .refreshable {
            forceRefreshIcons = true
            await manager.loadApps()
            forceRefreshIcons = false
        }
    }
}
