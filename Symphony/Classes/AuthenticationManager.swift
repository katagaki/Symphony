import Foundation
import Observation

@Observable
final class AuthenticationManager {
    var isDemoMode: Bool = false
    var isValidating: Bool = false
    var validationError: String?

    // Onboarding form fields, used when adding the first account.
    var issuerID: String = ""
    var keyID: String = ""
    var privateKeyText: String = ""

    private(set) var accounts: [Account] = []
    private(set) var selectedAccountID: UUID?
    private(set) var api: AppStoreConnectAPI?

    init() {
        loadFromKeychain()
    }

    var isAuthenticated: Bool {
        isDemoMode || !accounts.isEmpty
    }

    var selectedAccount: Account? {
        if let selectedAccountID,
           let match = accounts.first(where: { $0.id == selectedAccountID }) {
            return match
        }
        return accounts.first
    }

    var canConnect: Bool {
        !issuerID.trimmingCharacters(in: .whitespaces).isEmpty
            && !keyID.trimmingCharacters(in: .whitespaces).isEmpty
            && !privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Adds the first account from the onboarding form, named "Default".
    func saveCredentials() async {
        let didAdd = await addAccount(
            name: String(localized: "Accounts.DefaultName"),
            issuerID: issuerID,
            keyID: keyID,
            privateKey: privateKeyText
        )
        if didAdd {
            issuerID = ""
            keyID = ""
            privateKeyText = ""
        }
    }

    @discardableResult
    func addAccount(
        name: String,
        issuerID: String,
        keyID: String,
        privateKey: String
    ) async -> Bool {
        isValidating = true
        validationError = nil
        defer { isValidating = false }

        let creds = Credentials(
            issuerID: issuerID.trimmingCharacters(in: .whitespaces),
            keyID: keyID.trimmingCharacters(in: .whitespaces),
            privateKey: privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        do {
            let testAPI = AppStoreConnectAPI(client: APIClient(credentials: creds))
            _ = try await testAPI.listApps()

            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let account = Account(
                name: trimmedName.isEmpty ? String(localized: "Accounts.DefaultName") : trimmedName,
                issuerID: creds.issuerID,
                keyID: creds.keyID,
                privateKey: creds.privateKey
            )
            accounts.append(account)
            if selectedAccountID == nil {
                selectedAccountID = account.id
            }
            persist()
            updateAPI()
            return true
        } catch {
            validationError = error.localizedDescription
            return false
        }
    }

    func renameAccount(_ account: Account, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index].name = trimmed
        persist()
    }

    func deleteAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        if selectedAccountID == account.id {
            selectedAccountID = accounts.first?.id
        }
        persist()
        updateAPI()
    }

    func selectAccount(_ account: Account) {
        guard accounts.contains(where: { $0.id == account.id }) else { return }
        selectedAccountID = account.id
        persist()
        updateAPI()
    }

    func enterDemoMode() {
        isDemoMode = true
    }

    func signOut() {
        KeychainService.deleteAll()
        accounts = []
        selectedAccountID = nil
        api = nil
        isDemoMode = false
        issuerID = ""
        keyID = ""
        privateKeyText = ""
        validationError = nil
    }

    private func updateAPI() {
        guard let account = selectedAccount else {
            api = nil
            return
        }
        api = AppStoreConnectAPI(client: APIClient(credentials: account.credentials))
    }

    private func persist() {
        KeychainService.saveAccounts(accounts, selectedID: selectedAccountID)
    }

    private func loadFromKeychain() {
        if let storedAccounts = KeychainService.loadAccounts(), !storedAccounts.isEmpty {
            accounts = storedAccounts
            let storedSelection = KeychainService.loadSelectedAccountID()
            selectedAccountID = storedAccounts.contains(where: { $0.id == storedSelection })
                ? storedSelection
                : storedAccounts.first?.id
            updateAPI()
            return
        }

        // Migrate a legacy single-account credential set into a "Default" account.
        if let issuer = KeychainService.load(for: .issuerID),
           let key = KeychainService.load(for: .keyID),
           let pk = KeychainService.load(for: .privateKey) {
            let account = Account(
                name: String(localized: "Accounts.DefaultName"),
                issuerID: issuer,
                keyID: key,
                privateKey: pk
            )
            accounts = [account]
            selectedAccountID = account.id
            persist()
            KeychainService.deleteLegacyCredentials()
            updateAPI()
        }
    }
}
