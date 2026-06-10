import Foundation

nonisolated struct CiApp: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Codable, Sendable, Hashable {
        let name: String
        let bundleId: String
    }
}
