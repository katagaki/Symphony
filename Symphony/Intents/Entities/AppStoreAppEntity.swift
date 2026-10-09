import AppIntents

struct AppStoreAppEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Intents.Entity.App"
    static let defaultQuery = AppStoreAppQuery()

    let id: String
    @Property(title: "Intents.Property.Name")
    var name: String
    @Property(title: "Intents.Property.BundleID")
    var bundleID: String

    init(app: CiApp) {
        id = app.id
        name = app.attributes.name
        bundleID = app.attributes.bundleId
    }

    var app: CiApp {
        CiApp(id: id, attributes: .init(name: name, bundleId: bundleID))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(bundleID)")
    }
}

struct AppStoreAppQuery: EntityStringQuery {
    @Dependency private var authManager: AuthenticationManager

    func entities(for identifiers: [AppStoreAppEntity.ID]) async throws -> [AppStoreAppEntity] {
        try await apps().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [AppStoreAppEntity] {
        try await apps().filter {
            $0.name.localizedStandardContains(string) || $0.bundleID.localizedStandardContains(string)
        }
    }

    func suggestedEntities() async throws -> [AppStoreAppEntity] {
        try await apps()
    }

    /// The selected account's apps, from the cache when available so Shortcuts stays responsive.
    @MainActor
    private func apps() async throws -> [AppStoreAppEntity] {
        let api = try authManager.intentAPI()
        let apps: [CiApp]
        if let accountID = authManager.selectedAccount?.id.uuidString,
           let cached = AppListCache.shared.load(forAccountID: accountID),
           !cached.apps.isEmpty {
            apps = cached.apps
        } else {
            apps = try await api.listApps()
        }
        return apps
            .sorted { $0.attributes.name.localizedStandardCompare($1.attributes.name) == .orderedAscending }
            .map(AppStoreAppEntity.init(app:))
    }
}
