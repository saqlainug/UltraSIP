import Foundation

/// Domain description of a SIP account. Pure value; contains NO password —
/// only an opaque Keychain reference (CLAUDE.md security rules).
/// Milestone 1 scope: single account, UDP transport. Fields for later
/// milestones are added when their features land (SPEC §1) — no dead fields.
nonisolated struct SIPAccountConfig: Equatable, Identifiable, Sendable {
    enum Transport: String, CaseIterable, Sendable {
        case udp
    }

    var id: UUID
    /// Friendly label shown in UI.
    var label: String
    /// SIP domain, e.g. "pbx.example.com" (host or host:port).
    var domain: String
    /// Registrar URI override; empty = derive "sip:<domain>".
    var registrar: String
    var username: String
    /// Authentication ID; empty = use username.
    var authorizationID: String
    var displayName: String
    var transport: Transport
    /// Registration interval in seconds (0 = engine default of 300).
    var registrationInterval: Int
    /// Opaque Keychain item reference. NEVER the password itself.
    var keychainPasswordRef: String
    /// false = "local account": direct SIP/IP calls with no REGISTER
    /// (SPEC §1). The bridge skips registration when this is off.
    var registrationEnabled: Bool

    init(
        id: UUID = UUID(),
        label: String = "",
        domain: String = "",
        registrar: String = "",
        username: String = "",
        authorizationID: String = "",
        displayName: String = "",
        transport: Transport = .udp,
        registrationInterval: Int = 0,
        keychainPasswordRef: String = "",
        registrationEnabled: Bool = true
    ) {
        self.id = id
        self.label = label
        self.domain = domain
        self.registrar = registrar
        self.username = username
        self.authorizationID = authorizationID
        self.displayName = displayName
        self.transport = transport
        self.registrationInterval = registrationInterval
        self.keychainPasswordRef = keychainPasswordRef
        self.registrationEnabled = registrationEnabled
    }

    /// Address-of-record, e.g. "sip:alice@pbx.example.com".
    var aor: String { "sip:\(username)@\(domain)" }

    /// Registrar URI actually used.
    var effectiveRegistrar: String { registrar.isEmpty ? "sip:\(domain)" : registrar }

    enum ValidationError: Equatable, Sendable {
        case emptyUsername
        case emptyDomain
        case invalidDomain(String)
        case invalidRegistrar(String)
        case invalidRegistrationInterval(Int)

        var message: String {
            switch self {
            case .emptyUsername: "Username is required"
            case .emptyDomain: "SIP server is required"
            case .invalidDomain(let value): "Invalid SIP server: \(value)"
            case .invalidRegistrar(let value): "Invalid registrar: \(value)"
            case .invalidRegistrationInterval(let value): "Invalid registration interval: \(value)"
            }
        }
    }

    /// Structural validation. Empty result = safe to hand to the bridge.
    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        if username.isEmpty || username.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            errors.append(.emptyUsername)
        }
        if domain.isEmpty {
            errors.append(.emptyDomain)
        } else if !Self.isValidHostPort(domain) {
            errors.append(.invalidDomain(domain))
        }
        if !registrar.isEmpty {
            let stripped = registrar.hasPrefix("sip:") ? String(registrar.dropFirst(4)) : registrar
            if registrar.count > 255 || !Self.isValidHostPort(stripped) {
                errors.append(.invalidRegistrar(registrar))
            }
        }
        if registrationInterval < 0 || registrationInterval > 86400 {
            errors.append(.invalidRegistrationInterval(registrationInterval))
        }
        return errors
    }

    /// host, host:port, or bracketed IPv6 with optional port. Rejects
    /// whitespace/control characters (SIP header-injection guard).
    static func isValidHostPort(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 255 else { return false }
        guard value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
            value.rangeOfCharacter(from: .controlCharacters) == nil
        else { return false }

        var host = value
        if value.hasPrefix("[") {
            guard let close = value.firstIndex(of: "]") else { return false }
            host = String(value[value.index(after: value.startIndex)..<close])
            let rest = value[value.index(after: close)...]
            if !rest.isEmpty {
                guard rest.hasPrefix(":"), Self.isValidPort(String(rest.dropFirst())) else { return false }
            }
            return host.allSatisfy { $0.isHexDigit || $0 == ":" } && host.contains(":")
        }
        if let colon = value.lastIndex(of: ":"), value.firstIndex(of: ":") == colon {
            host = String(value[..<colon])
            guard Self.isValidPort(String(value[value.index(after: colon)...])) else { return false }
        }
        guard !host.isEmpty, host.count <= 253 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        return host.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func isValidPort(_ value: String) -> Bool {
        guard let port = Int(value) else { return false }
        return (1...65535).contains(port)
    }
}
