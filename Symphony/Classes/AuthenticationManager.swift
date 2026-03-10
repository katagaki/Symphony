import Foundation
import Observation

@Observable
final class AuthenticationManager {
    var isAuthenticated: Bool = false
    var isValidating: Bool = false
    var validationError: String?

    var issuerID: String = ""
    var keyID: String = ""
    var privateKeyText: String = ""

    private(set) var api: AppStoreConnectAPI?

    init() {
        loadFromKeychain()
    }

    var canConnect: Bool {
        !issuerID.trimmingCharacters(in: .whitespaces).isEmpty
            && !keyID.trimmingCharacters(in: .whitespaces).isEmpty
            && !privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveCredentials() async {
        isValidating = true
        validationError = nil

        do {
            let creds = Credentials(
                issuerID: issuerID.trimmingCharacters(in: .whitespaces),
                keyID: keyID.trimmingCharacters(in: .whitespaces),
                privateKey: privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let client = APIClient(credentials: creds)
            let testAPI = AppStoreConnectAPI(client: client)

            // Validate by making a test API call
            _ = try await testAPI.listApps()

            // Save to Keychain
            try KeychainService.save(creds.issuerID, for: .issuerID)
            try KeychainService.save(creds.keyID, for: .keyID)
            try KeychainService.save(creds.privateKey, for: .privateKey)

            self.api = testAPI
            isAuthenticated = true
        } catch {
            validationError = error.localizedDescription
        }

        isValidating = false
    }

    func signOut() {
        KeychainService.deleteAll()
        api = nil
        isAuthenticated = false
        issuerID = ""
        keyID = ""
        privateKeyText = ""
        validationError = nil
    }

    private func loadFromKeychain() {
        guard let issuer = KeychainService.load(for: .issuerID),
              let key = KeychainService.load(for: .keyID),
              let pk = KeychainService.load(for: .privateKey) else {
            return
        }
        issuerID = issuer
        keyID = key
        privateKeyText = pk

        let creds = Credentials(issuerID: issuer, keyID: key, privateKey: pk)
        let client = APIClient(credentials: creds)
        api = AppStoreConnectAPI(client: client)
        isAuthenticated = true
    }
}
