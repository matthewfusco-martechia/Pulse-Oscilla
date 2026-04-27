import CryptoKit
import Foundation
import UIKit

actor PairingManager {
    private let identityStore = DeviceIdentityStore()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func pair(rawPayload: String, transport: WebSocketTransport) async throws -> PairingResult {
        let payload = try decoder.decode(PairingPayload.self, from: Data(rawPayload.utf8))
        let deviceKey = try identityStore.loadOrCreatePrivateKey()
        let hostPublicKey = try hostKey(from: payload.hostPublicKey)
        let sharedSecret = try deviceKey.sharedSecretFromKeyAgreement(with: hostPublicKey)
        guard let salt = Data(base64Encoded: payload.nonce) else {
            throw PairingError.invalidNonce
        }

        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data("pulse-oscilla:\(payload.pairingId)".utf8),
            outputByteCount: 32
        )

        await transport.connect(to: payload.endpoint)
        let deviceName = await UIDevice.current.name
        let hello = PairingHelloEnvelope(payload: PairingHelloPayload(
            pairingId: payload.pairingId,
            deviceName: deviceName,
            devicePublicKey: deviceKey.publicKey.rawRepresentation.base64EncodedString(),
            deviceIdentityPublicKey: deviceKey.publicKey.rawRepresentation.base64EncodedString()
        ))
        try await transport.send(String(data: encoder.encode(hello), encoding: .utf8) ?? "{}")

        let encryptedAccepted = try decoder.decode(
            EncryptedFrame.self,
            from: Data(try await transport.receiveString().utf8)
        )
        let secureSession = SecureSession(sessionId: encryptedAccepted.sessionId, key: symmetricKey)
        let acceptedData = try await secureSession.decrypt(encryptedAccepted)
        let accepted = try decoder.decode(BridgeResponse<PairingAcceptedPayload>.self, from: acceptedData)

        return PairingResult(
            payload: payload,
            accepted: accepted.payload,
            secureSession: secureSession
        )
    }

    private func hostKey(from base64: String) throws -> Curve25519.KeyAgreement.PublicKey {
        guard let data = Data(base64Encoded: base64) else {
            throw PairingError.invalidHostKey
        }
        return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
    }
}

enum PairingError: Error {
    case invalidHostKey
    case invalidNonce
}
