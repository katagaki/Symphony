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
    /// The app shown in the detail column, when the apps are a split view sidebar.
    var selection: Binding<CiApp?>?
    @Environment(AuthenticationManager.self) private var authManager
    @State private var appsManager: AppsManager?
    @State private var sortOrder: AppSortOrder = .name
    @State private var searchText = ""
    @State private var forceRefreshIcons = false
    @State private var showAccounts = false
    @State private var showTeamID = false
    @State private var showDemoAccountsAlert = false
    @AppStorage("appsViewMode") private var viewMode: AppsViewMode = .list
    @Environment(\.openURL) private var openURL

    /// The sidebar column reports a compact size class, so split mode is told apart by the selection.
    private var isSidebar: Bool { selection != nil }

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
        .safeAreaInset(edge: .top) {
            if let manager = appsManager, manager.isShowingStaleData, !manager.apps.isEmpty {
                StaleDataBanner(lastUpdated: manager.lastUpdated) {
                    await manager.loadApps()
                }
            }
        }
        .animation(.smooth, value: appsManager?.isShowingStaleData == true)
        .searchable(text: $searchText, prompt: Text("Apps.SearchPrompt"))
        .animation(.smooth.speed(2.0), value: searchText)
        .navigationTitle("Apps.Title")
        .toolbar {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            if !isSidebar {
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItemGroup(placement: .bottomBar) {
                    sortMenu
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Group {
                    if appsManager?.isRefreshing == true {
                        ProgressView()
                    } else {
                        EmptyView()
                    }
                }
            }
            .sharedBackgroundVisibility(.hidden)
            if isSidebar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    sortMenu
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    accountMenu
                    moreMenu
                }
            } else {
                ToolbarItemGroup(placement: .topBarLeading) {
                    accountMenu
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    moreMenu
                }
            }
        }
        .sheet(isPresented: $showAccounts) {
            AccountsView()
        }
        .alert("Demo.AccountsUnavailable.Title", isPresented: $showDemoAccountsAlert) {
            Button("Shared.OK", role: .cancel) {}
        } message: {
            Text("Demo.AccountsUnavailable.Message")
        }
        .sheet(isPresented: $showTeamID) {
            TeamIDView()
        }
        .task(id: accountTaskID) {
            let manager: AppsManager
            if authManager.isDemoMode {
                manager = AppsManager(demoMode: true)
            } else {
                guard let api = authManager.api else { return }
                manager = AppsManager(api: api, accountID: authManager.selectedAccount?.id.uuidString)
            }
            appsManager = manager
            await manager.loadApps()
        }
    }

    private var sortMenu: some View {
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

    private var moreMenu: some View {
        Menu {
            Picker("Apps.ViewAs", selection: $viewMode) {
                ForEach(AppsViewMode.allCases, id: \.self) { mode in
                    Label(mode.localizedName, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
            Divider()
            if !authManager.isDemoMode {
                Button {
                    showTeamID = true
                } label: {
                    Label("TeamID.MenuItem", systemImage: "person.2.badge.key")
                }
            }
            Button(role: .destructive) {
                authManager.signOut()
            } label: {
                if authManager.isDemoMode {
                    Label("Shared.ExitDemoMode", systemImage: "rectangle.portrait.and.arrow.right")
                } else {
                    Label("Shared.SignOut", systemImage: "rectangle.portrait.and.arrow.right")
                }
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

    private var accountMenu: some View {
        Menu {
            if !authManager.isDemoMode {
                Section {
                    ForEach(authManager.accounts) { account in
                        Button {
                            authManager.selectAccount(account)
                        } label: {
                            if account.id == authManager.selectedAccount?.id {
                                Label(account.name, systemImage: "checkmark")
                            } else {
                                Text(account.name)
                            }
                        }
                    }
                }
            }
            Section {
                Button("Accounts.Manage") {
                    if authManager.isDemoMode {
                        showDemoAccountsAlert = true
                    } else {
                        showAccounts = true
                    }
                }
            }
        } label: {
            Image(systemName: "person.crop.circle")
        }
    }

    private func appsList(manager: AppsManager) -> some View {
        List(filteredAndSortedApps, selection: selection) { app in
            NavigationLink(value: app) {
                AppRowView(
                    app: app,
                    latestBuild: manager.latestBuildByApp[app.id],
                    forceRefreshIcons: forceRefreshIcons
                )
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
                columns: [GridItem(.adaptive(minimum: 70), spacing: 16, alignment: .top)],
                spacing: 16
            ) {
                ForEach(filteredAndSortedApps) { app in
                    gridLink(app: app) {
                        VStack(spacing: 8) {
                            AppIconView(app: app, forceRefresh: forceRefreshIcons)
                                .frame(width: 60, height: 60)
                                .overlay(alignment: .bottomTrailing) {
                                    if let latestBuild = manager.latestBuildByApp[app.id] {
                                        AppIconBuildBadge(build: latestBuild)
                                    }
                                }
                            Text(app.attributes.name)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, selection == nil ? 0 : 8)
                        .background {
                            if selection?.wrappedValue == app {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.tint.opacity(0.2))
                            }
                        }
                        .contentShape(.rect)
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

    @ViewBuilder
    private func gridLink<Label: View>(app: CiApp, @ViewBuilder label: () -> Label) -> some View {
        if let selection {
            Button {
                selection.wrappedValue = app
            } label: {
                label()
            }
        } else {
            NavigationLink(value: app, label: label)
        }
    }
}
