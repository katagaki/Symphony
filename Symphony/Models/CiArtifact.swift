import Foundation

nonisolated struct CiArtifact: Decodable, Identifiable, Sendable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Decodable, Sendable {
        let fileName: String?
        let fileSize: Int?
        let downloadUrl: String?
    }
}
