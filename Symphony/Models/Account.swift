import Foundation

nonisolated struct Account: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    let issuerID: String
    let keyID: String
    let privateKey: String

    init(
        id: UUID = UUID(),
        name: String,
        issuerID: String,
        keyID: String,
        privateKey: String
    ) {
        self.id = id
        self.name = name
        self.issuerID = issuerID
        self.keyID = keyID
        self.privateKey = privateKey
    }

    var credentials: Credentials {
        Credentials(issuerID: issuerID, keyID: keyID, privateKey: privateKey)
    }
}
