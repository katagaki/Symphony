import Foundation

nonisolated struct CiProduct: Decodable, Identifiable, Sendable {
    let id: String
    let attributes: Attributes

    nonisolated struct Attributes: Decodable, Sendable {
        let name: String
        let createdDate: String?
        let productType: String?
    }
}
