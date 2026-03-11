import Foundation

nonisolated struct APIResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
    let links: APILinks?
}

nonisolated struct APIListResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: [T]
    let links: APIPaginationLinks?
}

nonisolated struct APILinks: Decodable, Sendable {
    let `self`: String?
}

nonisolated struct APIPaginationLinks: Decodable, Sendable {
    let `self`: String?
    let next: String?
}

nonisolated struct APIListResponseWithIncludes<T: Decodable & Sendable, I: Decodable & Sendable>: Decodable, Sendable {
    let data: [T]
    let included: [I]
    let links: APIPaginationLinks?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode([T].self, forKey: .data)
        included = (try? container.decode([I].self, forKey: .included)) ?? []
        links = try? container.decode(APIPaginationLinks.self, forKey: .links)
    }

    enum CodingKeys: String, CodingKey {
        case data, included, links
    }
}

nonisolated struct APIResourceIdentifier: Codable, Sendable, Hashable {
    let type: String
    let id: String
}

nonisolated struct APIRelationship: Decodable, Sendable {
    let data: APIRelationshipData?
    let links: APIRelationshipLinks?
}

nonisolated struct APIRelationshipLinks: Decodable, Sendable {
    let related: String?
}

nonisolated enum APIRelationshipData: Sendable {
    case single(APIResourceIdentifier)
    case many([APIResourceIdentifier])

    var singleID: String? {
        if case .single(let identifier) = self {
            return identifier.id
        }
        return nil
    }
}

extension APIRelationshipData: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(APIResourceIdentifier.self) {
            self = .single(single)
        } else if let many = try? container.decode([APIResourceIdentifier].self) {
            self = .many(many)
        } else {
            throw DecodingError.typeMismatch(
                APIRelationshipData.self,
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Expected single or array of resource identifiers")
            )
        }
    }
}
