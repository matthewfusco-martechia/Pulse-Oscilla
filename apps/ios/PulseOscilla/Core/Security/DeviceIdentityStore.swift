import CryptoKit
import Foundation
import Security

final class DeviceIdentityStore {
    private let service = "com.pulseoscilla.device-identity"
    private let account = "x25519"

    func loadOrCreatePrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        if let data = try loadKeyData() {
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
        }

        let key = Curve25519.KeyAgreement.PrivateKey()
        try saveKeyData(key.rawRepresentation)
        return key
    }

    private func loadKeyData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
        return result as? Data
    }

    private func saveKeyData(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}

enum KeychainError: Error {
    case unhandledStatus(OSStatus)
}

