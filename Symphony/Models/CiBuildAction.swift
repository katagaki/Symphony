import Foundation

nonisolated struct CiBuildAction: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Decodable, Sendable, Hashable {
        let name: String?
        let actionType: String?
        let executionProgress: ExecutionProgress?
        let completionStatus: CompletionStatus?
        let startedDate: String?
        let finishedDate: String?
        let issueCounts: IssueCounts?
    }

    nonisolated struct IssueCounts: Decodable, Sendable, Hashable {
        let analyzerWarnings: Int?
        let errors: Int?
        let testFailures: Int?
        let warnings: Int?
    }
}
