import Foundation

nonisolated struct ScmPullRequest: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Decodable, Sendable, Hashable {
        let title: String?
        let number: Int?
        let webUrl: String?
        let sourceBranchName: String?
        let destinationBranchName: String?
        let isClosed: Bool?
        let isCrossRepository: Bool?
    }
}
