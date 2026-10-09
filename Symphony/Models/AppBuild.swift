import Foundation

/// A build uploaded to App Store Connect (the `builds` resource), as opposed to an Xcode Cloud build run.
nonisolated struct AppBuild: Codable, Identifiable, Sendable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Codable, Sendable {
        let uploadedDate: String?
        let processingState: String?
        let iconAssetToken: ImageAsset?
    }
}

nonisolated struct ImageAsset: Codable, Sendable {
    let templateUrl: String
    let width: Int?
    let height: Int?

    /// Fills in the `{w}x{h}bb.{f}` placeholders of the template URL.
    func url(size: Int, format: String = "png") -> URL? {
        URL(string: templateUrl
            .replacingOccurrences(of: "{w}", with: "\(size)")
            .replacingOccurrences(of: "{h}", with: "\(size)")
            .replacingOccurrences(of: "{f}", with: format))
    }
}
