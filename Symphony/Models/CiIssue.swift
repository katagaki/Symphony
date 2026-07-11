import Foundation

nonisolated struct CiIssue: Decodable, Identifiable, Sendable, Hashable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Decodable, Sendable, Hashable {
        let issueType: IssueType?
        let message: String?
        let fileSource: FileSource?
        let category: String?
    }

    nonisolated struct FileSource: Decodable, Sendable, Hashable {
        let path: String?
        let lineNumber: Int?
    }

    nonisolated enum IssueType: String, Decodable, Sendable, Hashable {
        case analyzerWarning = "ANALYZER_WARNING"
        case error = "ERROR"
        case testFailure = "TEST_FAILURE"
        case warning = "WARNING"
    }
}
