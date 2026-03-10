import Foundation

nonisolated struct GitReference: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Decodable, Sendable, Hashable {
        let name: String
        let kind: Kind?
        let isDeleted: Bool?
    }

    nonisolated enum Kind: String, Decodable, Sendable, Hashable {
        case branch = "BRANCH"
        case tag = "TAG"
    }
}
