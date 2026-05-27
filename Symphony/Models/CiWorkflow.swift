import Foundation

nonisolated struct CiWorkflow: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes
    let relationships: Relationships?

    nonisolated struct Attributes: Codable, Sendable, Hashable {
        let name: String
        let description: String?
        let lastModifiedDate: String?
        let isEnabled: Bool?
        let isLockedForEditing: Bool?
    }

    nonisolated struct Relationships: Codable, Sendable, Hashable {
        let repository: RepositoryRelationship?

        nonisolated struct RepositoryRelationship: Codable, Sendable, Hashable {
            let data: APIResourceIdentifier?
        }
    }
}
