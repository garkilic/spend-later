import Foundation
import Security
import CryptoKit

final class PasscodeManager {
    private var currentKey: String?

    func setActiveKey(_ key: String?) {
        currentKey = key
    }

    @discardableResult
    func setPasscode(_ passcode: String) throws -> String {
        let key = "spendlater.passcode." + UUID().uuidString
        let salt = try secureRandom(count: 16)
        let hash = hash(passcode: passcode, salt: salt)
        let payload = PasscodePayload(salt: salt, hash: hash)
        try store(payload: payload, for: key)
        currentKey = key
        return key
    }

    func validate(_ passcode: String) -> Bool {
        guard let key = currentKey, let payload = loadPayload(for: key) else { return false }
        let candidate = hash(passcode: passcode, salt: payload.salt)
        return constantTimeEquals(lhs: candidate, rhs: payload.hash)
    }

    func clear() {
        guard let key = currentKey else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecAttrService as String: "spendlater.passcode"]
        SecItemDelete(query as CFDictionary)
        currentKey = nil
    }
}

private extension PasscodeManager {
    struct PasscodePayload: Codable {
        let salt: Data
        let hash: Data
    }

    func secureRandom(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
        return Data(bytes)
    }

    func hash(passcode: String, salt: Data) -> Data {
        let passcodeData = Data(passcode.utf8)
        var data = Data()
        data.append(salt)
        data.append(passcodeData)
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }

    func constantTimeEquals(lhs: Data, rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for i in 0..<lhs.count {
            difference |= lhs[i] ^ rhs[i]
        }
        return difference == 0
    }

    func store(payload: PasscodePayload, for key: String) throws {
        let data = try JSONEncoder().encode(payload)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "spendlater.passcode",
            kSecValueData as String: data
        ]
        SecItemDelete(attributes as CFDictionary)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
    }

    func loadPayload(for key: String) -> PasscodePayload? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "spendlater.passcode",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(PasscodePayload.self, from: data)
    }
}
