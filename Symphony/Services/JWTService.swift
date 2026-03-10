import Foundation
import CryptoKit

nonisolated enum JWTService {
    nonisolated enum JWTError: LocalizedError {
        case invalidPrivateKey
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidPrivateKey:
                return "Invalid private key. Ensure you've provided a valid .p8 file."
            case .encodingFailed:
                return "Failed to encode JWT."
            }
        }
    }

    nonisolated static func generateToken(
        issuerID: String,
        keyID: String,
        privateKeyPEM: String
    ) throws -> String {
        let privateKey = try parsePrivateKey(from: privateKeyPEM)

        let header = try base64URLEncode(json: [
            "alg": "ES256",
            "kid": keyID,
            "typ": "JWT"
        ])

        let now = Int(Date().timeIntervalSince1970)
        let payload = try base64URLEncode(json: [
            "iss": issuerID,
            "iat": now,
            "exp": now + 1200,
            "aud": "appstoreconnect-v1"
        ] as [String: Any])

        let signingInput = "\(header).\(payload)"
        guard let signingData = signingInput.data(using: .utf8) else {
            throw JWTError.encodingFailed
        }

        let signature = try privateKey.signature(for: signingData)
        let signatureB64 = base64URLEncode(data: signature.rawRepresentation)

        return "\(header).\(payload).\(signatureB64)"
    }

    private nonisolated static func parsePrivateKey(from pem: String) throws -> P256.Signing.PrivateKey {
        let stripped = pem
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let keyData = Data(base64Encoded: stripped) else {
            throw JWTError.invalidPrivateKey
        }

        do {
            return try P256.Signing.PrivateKey(derRepresentation: keyData)
        } catch {
            throw JWTError.invalidPrivateKey
        }
    }

    private nonisolated static func base64URLEncode(json: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        return base64URLEncode(data: data)
    }

    private nonisolated static func base64URLEncode(data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
