import Foundation

struct PairingPayload: Codable, Hashable {
    let v: Int
    let endpoint: URL
    let pairingId: String
    let hostPublicKey: String
    let nonce: String
    let fingerprint: String
    let workspaceHint: String?
    let expiresAt: String
}

struct PairingHelloPayload: Codable {
    let pairingId: String
    let deviceName: String
    let devicePublicKey: String
    let deviceIdentityPublicKey: String
}

struct PairingHelloEnvelope: Encodable {
    let type = "pairing.hello"
    let payload: PairingHelloPayload
}

struct PairingAcceptedPayload: Codable, Hashable {
    let sessionId: String
    let resumeToken: String
    let hostPublicKey: String
    let capabilities: [Capability]
    let workspaceId: String
    let workspaceRoot: String
}

struct EncryptedFrame: Codable {
    let kind: String
    let sessionId: String
    let sequence: Int
    let nonce: String
    let ciphertext: String
    let tag: String
}

struct PairingResult {
    let payload: PairingPayload
    let accepted: PairingAcceptedPayload
    let secureSession: SecureSession
}

