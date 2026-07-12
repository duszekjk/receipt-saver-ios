import Foundation
import Security

struct AppLoginPayload: Codable {
    let type: String
    let device_id: String
    let secret_key: String
}

struct AppCredentials: Codable, Equatable {
    let deviceID: String
    let secretKey: String

    init(payload: AppLoginPayload) {
        self.deviceID = payload.device_id
        self.secretKey = payload.secret_key
    }

    init(deviceID: String, secretKey: String) {
        self.deviceID = deviceID
        self.secretKey = secretKey
    }
}

protocol CredentialStoring: AnyObject {
    func load() -> AppCredentials?
    func save(_ credentials: AppCredentials) throws
    func delete()
}

final class CredentialStore: CredentialStoring {
    static let shared = CredentialStore()
    private let service = "ReceiptSaver"
    private let account = "AppCredentials"

    private init() {}

    func load() -> AppCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AppCredentials.self, from: data)
    }

    func save(_ credentials: AppCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String
        ]
        SecItemDelete(query as CFDictionary)
    }
}
