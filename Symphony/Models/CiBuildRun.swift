import Foundation

nonisolated struct CiBuildRun: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes
    let relationships: Relationships?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CiBuildRun, rhs: CiBuildRun) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated struct Attributes: Decodable, Sendable {
        let number: Int?
        let createdDate: String?
        let startedDate: String?
        let finishedDate: String?
        let sourceCommit: SourceCommit?
        let executionProgress: ExecutionProgress?
        let completionStatus: CompletionStatus?
        let isPullRequestBuild: Bool?
    }

    nonisolated struct SourceCommit: Decodable, Sendable {
        let commitSha: String?
        let message: String?
        let author: Author?

        nonisolated struct Author: Decodable, Sendable {
            let displayName: String?
        }
    }

    nonisolated struct Relationships: Decodable, Sendable {
        let workflow: WorkflowRelationship?

        nonisolated struct WorkflowRelationship: Decodable, Sendable {
            let data: APIResourceIdentifier?
        }
    }
}

nonisolated enum ExecutionProgress: String, Decodable, Sendable {
    case pending = "PENDING"
    case running = "RUNNING"
    case complete = "COMPLETE"
}

nonisolated enum CompletionStatus: String, Decodable, Sendable {
    case succeeded = "SUCCEEDED"
    case failed = "FAILED"
    case errored = "ERRORED"
    case canceled = "CANCELED"
    case skipped = "SKIPPED"
}
