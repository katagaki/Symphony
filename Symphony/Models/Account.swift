import Foundation

nonisolated struct Account: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    let issuerID: String
    let keyID: String
    let privateKey: String
    // App Store Connect web team ID (the UUID in appstoreconnect.apple.com/teams/<teamID>/...),
    // not available via the API, so the user provides it manually.
    var teamID: String?

    init(
        id: UUID = UUID(),
        name: String,
        issuerID: String,
        keyID: String,
        privateKey: String,
        teamID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.issuerID = issuerID
        self.keyID = keyID
        self.privateKey = privateKey
        self.teamID = teamID
    }

    var credentials: Credentials {
        Credentials(issuerID: issuerID, keyID: keyID, privateKey: privateKey)
    }
}
