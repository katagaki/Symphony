import Foundation

nonisolated struct CiBuildRun: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes
    let relationships: Relationships?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CiBuildRun, rhs: CiBuildRun) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated struct Attributes: Codable, Sendable {
        let number: Int?
        let createdDate: String?
        let startedDate: String?
        let finishedDate: String?
        let sourceCommit: SourceCommit?
        let executionProgress: ExecutionProgress?
        let completionStatus: CompletionStatus?
        let isPullRequestBuild: Bool?
    }

    nonisolated struct SourceCommit: Codable, Sendable {
        let commitSha: String?
        let message: String?
        let author: Author?

        nonisolated struct Author: Codable, Sendable {
            let displayName: String?
        }
    }

    nonisolated struct Relationships: Codable, Sendable {
        let workflow: ResourceRelationship?
        let sourceBranchOrTag: ResourceRelationship?

        nonisolated struct ResourceRelationship: Codable, Sendable {
            let data: APIResourceIdentifier?
        }
    }
}

nonisolated enum ExecutionProgress: String, Codable, Sendable {
    case pending = "PENDING"
    case running = "RUNNING"
    case complete = "COMPLETE"
}

nonisolated enum CompletionStatus: String, Codable, Sendable {
    case succeeded = "SUCCEEDED"
    case failed = "FAILED"
    case errored = "ERRORED"
    case canceled = "CANCELED"
    case skipped = "SKIPPED"
}
