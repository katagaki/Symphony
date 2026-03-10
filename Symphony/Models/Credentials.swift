import Foundation

nonisolated struct Credentials: Sendable {
    let issuerID: String
    let keyID: String
    let privateKey: String
}
