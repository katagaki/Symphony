import Foundation

nonisolated struct CiWorkflow: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes
    let relationships: Relationships?

    nonisolated struct Attributes: Decodable, Sendable, Hashable {
        let name: String
        let description: String?
        let lastModifiedDate: String?
        let isEnabled: Bool?
        let isLockedForEditing: Bool?
    }

    nonisolated struct Relationships: Decodable, Sendable, Hashable {
        let repository: RepositoryRelationship?

        nonisolated struct RepositoryRelationship: Decodable, Sendable, Hashable {
            let data: APIResourceIdentifier?
        }
    }
}
