import Foundation
import Security

/// Storage for SIP secrets. The rest of the app deals only in opaque refs
/// (CLAUDE.md: Keychain only; DB stores stable references; never plaintext).
nonisolated protocol SecretStore: Sendable {
    func setPassword(_ password: String, forRef ref: String) throws
    func password(forRef ref: String) throws -> String?
    func deletePassword(forRef ref: String) throws
}

nonisolated enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case notUTF8
}

/// Generic-password Keychain items, service-scoped to the app.
nonisolated struct KeychainStore: SecretStore {
    let service: String
    /// Service strings used by earlier releases. The service is derived from
    /// the bundle identifier, so the MacSIP→UltraSIP rebrand moved it — a
    /// read miss falls back here and migrates the secret forward once, so
    /// upgrading users are not silently asked to re-enter every password.
    let legacyServices: [String]

    init(
        service: String = (Bundle.main.bundleIdentifier ?? "com.ultranet.ultrasip") + ".sip-account",
        legacyServices: [String] = ["com.example.macsip.sip-account"]
    ) {
        self.service = service
        self.legacyServices = legacyServices.filter { $0 != service }
    }

    private func baseQuery(ref: String) -> [String: Any] {
        baseQuery(ref: ref, service: service)
    }

    private func baseQuery(ref: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: ref,
        ]
    }

    func setPassword(_ password: String, forRef ref: String) throws {
        let data = Data(password.utf8)
        var query = baseQuery(ref: ref)
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            status = SecItemAdd(query as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    func password(forRef ref: String) throws -> String? {
        if let password = try password(forRef: ref, service: service) {
            return password
        }
        // Miss under the current service: adopt a secret left behind by an
        // earlier product name, then serve it from the new service.
        for legacy in legacyServices {
            guard let password = try? password(forRef: ref, service: legacy) else { continue }
            try setPassword(password, forRef: ref)
            try? deletePassword(forRef: ref, service: legacy)
            return password
        }
        return nil
    }

    private func password(forRef ref: String, service: String) throws -> String? {
        var query = baseQuery(ref: ref, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.notUTF8
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func deletePassword(forRef ref: String) throws {
        try deletePassword(forRef: ref, service: service)
        // A deleted account must not leave its secret behind under an old
        // service name.
        for legacy in legacyServices {
            try? deletePassword(forRef: ref, service: legacy)
        }
    }

    private func deletePassword(forRef ref: String, service: String) throws {
        let status = SecItemDelete(baseQuery(ref: ref, service: service) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

/// Test/preview double — never used in release paths.
nonisolated final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let lock = NSLock()

    func setPassword(_ password: String, forRef ref: String) throws {
        lock.withLock { storage[ref] = password }
    }

    func password(forRef ref: String) throws -> String? {
        lock.withLock { storage[ref] }
    }

    func deletePassword(forRef ref: String) throws {
        lock.withLock { storage[ref] = nil }
    }
}
