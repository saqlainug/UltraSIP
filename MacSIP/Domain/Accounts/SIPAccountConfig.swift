import Foundation

/// Domain description of a SIP account. Pure value; contains NO password —
/// only an opaque Keychain reference (CLAUDE.md security rules).
/// Milestone 1 scope: single account, UDP transport. Fields for later
/// milestones are added when their features land (SPEC §1) — no dead fields.
nonisolated struct SIPAccountConfig: Equatable, Identifiable, Sendable {
    enum Transport: String, CaseIterable, Sendable {
        /// RFC 3263 selection: UDP with automatic TCP for large requests
        /// (MicroSIP "UDP+TCP" mode).
        case auto
        /// Forces ;transport=udp on the registrar.
        case udp
        case tcp
        case tls

        var displayName: String {
            switch self {
            case .auto: "UDP + TCP (auto)"
            case .udp: "UDP"
            case .tcp: "TCP"
            case .tls: "TLS"
            }
        }
    }

    enum SessionTimerMode: String, CaseIterable, Sendable {
        case off
        case optional
        case required
    }

    /// SPEC §2 media-encryption policy. DTLS-SRTP is out of scope by
    /// decision (2026-07-13); SDES is the supported keying.
    enum MediaEncryption: String, CaseIterable, Sendable {
        case none
        case srtpOptional = "srtp-optional"
        case srtpMandatory = "srtp-mandatory"
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
    var mediaEncryption: MediaEncryption
    /// Per-account TLS trust override (SPEC §2): visible in UI, default
    /// OFF. When on, server certificates are NOT verified — never enable
    /// silently, never global.
    var tlsVerificationDisabled: Bool
    /// NAT traversal (SPEC §1): STUN server ("host[:port]", empty = none).
    var stunServer: String
    var iceEnabled: Bool
    /// TURN relay ("host[:port]", empty = none). The TURN credential is a
    /// secret: only its Keychain ref lives here, like the SIP password.
    var turnServer: String
    var turnUsername: String
    var turnPasswordRef: String
    /// Outbound proxy ("host[:port]" or full sip: URI; empty = none) —
    /// routes ALL account requests when set (SPEC §1/§2).
    var outboundProxy: String
    /// UDP keepalive seconds (0 = stack default).
    var keepaliveInterval: Int
    var sessionTimerMode: SessionTimerMode
    /// Session-Expires seconds (0 = stack default; else ≥ 90, RFC 4028).
    var sessionTimerExpiry: Int
    /// NAT rewrites (MicroSIP "Allow IP rewrite" family); default on.
    var contactRewrite: Bool
    var viaRewrite: Bool
    var voicemailNumber: String
    /// Prepended to bare dialed numbers only (SPEC §3 dialing prefix).
    var dialPrefix: String

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
        registrationEnabled: Bool = true,
        mediaEncryption: MediaEncryption = .none,
        tlsVerificationDisabled: Bool = false,
        stunServer: String = "",
        iceEnabled: Bool = false,
        turnServer: String = "",
        turnUsername: String = "",
        turnPasswordRef: String = "",
        outboundProxy: String = "",
        keepaliveInterval: Int = 0,
        sessionTimerMode: SessionTimerMode = .optional,
        sessionTimerExpiry: Int = 0,
        contactRewrite: Bool = true,
        viaRewrite: Bool = true,
        voicemailNumber: String = "",
        dialPrefix: String = ""
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
        self.mediaEncryption = mediaEncryption
        self.tlsVerificationDisabled = tlsVerificationDisabled
        self.stunServer = stunServer
        self.iceEnabled = iceEnabled
        self.turnServer = turnServer
        self.turnUsername = turnUsername
        self.turnPasswordRef = turnPasswordRef
        self.outboundProxy = outboundProxy
        self.keepaliveInterval = keepaliveInterval
        self.sessionTimerMode = sessionTimerMode
        self.sessionTimerExpiry = sessionTimerExpiry
        self.contactRewrite = contactRewrite
        self.viaRewrite = viaRewrite
        self.voicemailNumber = voicemailNumber
        self.dialPrefix = dialPrefix
    }

    /// URI transport parameter ("" for auto = RFC 3263 selection).
    var transportParameter: String {
        transport == .auto ? "" : ";transport=\(transport.rawValue)"
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
        case invalidSTUNServer(String)
        case invalidTURNServer(String)
        case invalidOutboundProxy(String)
        case invalidKeepalive(Int)
        case invalidSessionTimerExpiry(Int)
        case invalidVoicemailNumber(String)
        case invalidDialPrefix(String)

        var message: String {
            switch self {
            case .emptyUsername: "Username is required"
            case .emptyDomain: "SIP server is required"
            case .invalidDomain(let value): "Invalid SIP server: \(value)"
            case .invalidRegistrar(let value): "Invalid registrar: \(value)"
            case .invalidRegistrationInterval(let value): "Invalid registration interval: \(value)"
            case .invalidSTUNServer(let value): "Invalid STUN server: \(value)"
            case .invalidTURNServer(let value): "Invalid TURN server: \(value)"
            case .invalidOutboundProxy(let value): "Invalid outbound proxy: \(value)"
            case .invalidKeepalive(let value): "Invalid keepalive interval: \(value)"
            case .invalidSessionTimerExpiry(let value): "Session timer expiry must be 0 or ≥ 90 s: \(value)"
            case .invalidVoicemailNumber(let value): "Invalid voicemail number: \(value)"
            case .invalidDialPrefix(let value): "Invalid dialing prefix: \(value)"
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
        if !stunServer.isEmpty, !Self.isValidHostPort(stunServer) {
            errors.append(.invalidSTUNServer(stunServer))
        }
        if !turnServer.isEmpty, !Self.isValidHostPort(turnServer) {
            errors.append(.invalidTURNServer(turnServer))
        }
        if !outboundProxy.isEmpty {
            let stripped = outboundProxy.hasPrefix("sip:") ? String(outboundProxy.dropFirst(4)) : outboundProxy
            if outboundProxy.count > 255 || !Self.isValidHostPort(stripped) {
                errors.append(.invalidOutboundProxy(outboundProxy))
            }
        }
        if keepaliveInterval < 0 || keepaliveInterval > 3600 {
            errors.append(.invalidKeepalive(keepaliveInterval))
        }
        if sessionTimerExpiry != 0, !(90...7200).contains(sessionTimerExpiry) {
            errors.append(.invalidSessionTimerExpiry(sessionTimerExpiry))
        }
        let dialable = CharacterSet(charactersIn: "0123456789*#+")
        if !voicemailNumber.isEmpty,
            voicemailNumber.count > 32
                || !voicemailNumber.unicodeScalars.allSatisfy({ dialable.contains($0) })
        {
            errors.append(.invalidVoicemailNumber(voicemailNumber))
        }
        if !dialPrefix.isEmpty,
            dialPrefix.count > 16 || !dialPrefix.unicodeScalars.allSatisfy({ dialable.contains($0) })
        {
            errors.append(.invalidDialPrefix(dialPrefix))
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
