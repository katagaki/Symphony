import Foundation

nonisolated struct CiApp: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Decodable, Sendable, Hashable {
        let name: String
        let bundleId: String
    }
}
