import Foundation

/// A build uploaded to App Store Connect (the `builds` resource), as opposed to an Xcode Cloud build run.
nonisolated struct AppBuild: Codable, Identifiable, Sendable {
    let id: String
    let attributes: Attributes
    let relationships: Relationships?
    /// Resolved from the included pre-release version; not part of the build resource itself.
    var platform: Platform?

    private enum CodingKeys: String, CodingKey {
        case id, attributes, relationships
    }

    nonisolated struct Attributes: Codable, Sendable {
        let uploadedDate: String?
        let processingState: String?
        let iconAssetToken: ImageAsset?
    }

    nonisolated struct Relationships: Codable, Sendable {
        let preReleaseVersion: RelationshipData?
    }

    nonisolated struct RelationshipData: Codable, Sendable {
        let data: ResourceIdentifier?
    }

    nonisolated struct ResourceIdentifier: Codable, Sendable {
        let id: String
    }

    nonisolated enum Platform: String, Codable, Sendable {
        case iOS = "IOS"
        case macOS = "MAC_OS"
        case tvOS = "TV_OS"
        case visionOS = "VISION_OS"
    }
}

/// The version and platform a build belongs to (the `preReleaseVersions` resource).
nonisolated struct PreReleaseVersion: Codable, Identifiable, Sendable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Codable, Sendable {
        /// Kept as a string so platforms added later don't fail decoding.
        let platform: String?
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
