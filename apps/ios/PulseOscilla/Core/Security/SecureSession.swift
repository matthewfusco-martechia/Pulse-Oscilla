import CryptoKit
import Foundation

actor SecureSession {
    let sessionId: String
    private let key: SymmetricKey
    private var sendSequence = 0

    init(sessionId: String, key: SymmetricKey) {
        self.sessionId = sessionId
        self.key = key
    }

    func encrypt(_ data: Data) throws -> EncryptedFrame {
        sendSequence += 1
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(
            data,
            using: key,
            nonce: nonce,
            authenticating: aad(sequence: sendSequence)
        )

        return EncryptedFrame(
            kind: "secure.message",
            sessionId: sessionId,
            sequence: sendSequence,
            nonce: Data(nonce).base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString(),
            tag: sealed.tag.base64EncodedString()
        )
    }

    func decrypt(_ frame: EncryptedFrame) throws -> Data {
        guard frame.sessionId == sessionId else {
            throw SecureSessionError.sessionMismatch
        }
        guard
            let nonceData = Data(base64Encoded: frame.nonce),
            let ciphertext = Data(base64Encoded: frame.ciphertext),
            let tag = Data(base64Encoded: frame.tag)
        else {
            throw SecureSessionError.invalidFrameEncoding
        }

        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonceData),
            ciphertext: ciphertext,
            tag: tag
        )
        return try AES.GCM.open(sealedBox, using: key, authenticating: aad(sequence: frame.sequence))
    }

    private func aad(sequence: Int) -> Data {
        Data("\(sessionId):\(sequence)".utf8)
    }
}

enum SecureSessionError: Error {
    case sessionMismatch
    case invalidFrameEncoding
}

