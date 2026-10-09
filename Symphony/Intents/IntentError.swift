import AppIntents

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case notSignedIn
    case noRepository

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSignedIn: "Intents.Error.NotSignedIn"
        case .noRepository: "Intents.Error.NoRepository"
        }
    }
}

extension AuthenticationManager {
    /// The API for the selected account, or an error Shortcuts can show when there isn't one.
    func intentAPI() throws -> AppStoreConnectAPI {
        guard let api else { throw IntentError.notSignedIn }
        return api
    }
}
