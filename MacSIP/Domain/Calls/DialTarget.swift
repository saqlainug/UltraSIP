import Foundation

/// Parses and validates user dial input into a SIP URI for the bridge.
/// Milestone 1 scope: extensions/numbers, user@host, full sip:/sips: URIs,
/// IPv4/IPv6 hosts. Dial plans/prefixes arrive with their SPEC §3 slice.
/// Security: rejects control characters and whitespace (SIP header
/// injection) and bounds length — tested in DialTargetTests.
nonisolated enum DialTarget {
    enum ParseError: Error, Equatable, Sendable {
        case empty
        case tooLong
        case illegalCharacters
        case invalidURI

        var message: String {
            switch self {
            case .empty: "Enter a number or SIP address"
            case .tooLong: "Destination is too long"
            case .illegalCharacters: "Destination contains invalid characters"
            case .invalidURI: "Not a valid number or SIP address"
            }
        }
    }

    static let maxLength = 256

    /// Characters permitted in the user/host parts of dial input
    /// (conservative subset of RFC 3261; expanded when URI-params land).
    private static let allowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            + "-_.+*#@:[]")

    /// SPEC §3 dialing prefix: applied to BARE numbers only — never to
    /// URIs, user@host forms, or host targets (prefixes must not corrupt
    /// meaningful SIP syntax).
    static func applyingDialPrefix(_ prefix: String, to input: String) -> String {
        guard !prefix.isEmpty else { return input }
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let bareNumber = CharacterSet(charactersIn: "0123456789*#+")
        guard !trimmed.isEmpty,
            trimmed.unicodeScalars.allSatisfy({ bareNumber.contains($0) })
        else { return input }
        return prefix + trimmed
    }

    /// Returns the SIP URI to dial, resolving bare numbers against the
    /// account domain.
    static func parse(_ input: String, accountDomain: String) -> Result<String, ParseError> {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard trimmed.count <= maxLength else { return .failure(.tooLong) }
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
            trimmed.rangeOfCharacter(from: .controlCharacters) == nil
        else { return .failure(.illegalCharacters) }

        var body = trimmed
        var scheme = "sip"
        if let match = trimmed.range(of: "^sips?:", options: [.regularExpression, .caseInsensitive]) {
            scheme = trimmed[match].lowercased().hasPrefix("sips") ? "sips" : "sip"
            body = String(trimmed[match.upperBound...])
        }
        guard !body.isEmpty else { return .failure(.invalidURI) }
        guard body.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return .failure(.illegalCharacters)
        }

        if body.contains("@") {
            let parts = body.split(separator: "@", omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty,
                SIPAccountConfig.isValidHostPort(String(parts[1]))
            else { return .failure(.invalidURI) }
            return .success("\(scheme):\(body)")
        }

        // Bare user part (extension/number) → dial against the account domain.
        guard !accountDomain.isEmpty else { return .failure(.invalidURI) }
        guard body.first != ":", !body.contains(":") || SIPAccountConfig.isValidHostPort(body) else {
            // "host:port" without user — direct IP/host dialing.
            return .success("\(scheme):\(body)")
        }
        if SIPAccountConfig.isValidHostPort(body), body.contains(".") || body.contains(":") {
            // Looks like a bare host/IP — direct dialing target.
            return .success("\(scheme):\(body)")
        }
        return .success("\(scheme):\(body)@\(accountDomain)")
    }
}
