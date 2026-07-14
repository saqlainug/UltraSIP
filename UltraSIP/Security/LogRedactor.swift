import Foundation

/// Redaction helpers for log/diagnostic sites (CLAUDE.md: DTMF sequences,
/// credentials, and auth data never appear in logs; automated tests extend
/// with every new log site).
nonisolated enum LogRedactor {
    /// DTMF may carry PINs — only the count is loggable.
    static func redactDTMF(_ digits: String) -> String {
        "<\(digits.count) DTMF digit\(digits.count == 1 ? "" : "s")>"
    }

    /// Removes password-bearing query/parameter fragments from URIs before
    /// logging (defensive; UltraSIP never builds such URIs itself).
    static func redactURI(_ uri: String) -> String {
        guard let range = uri.range(of: "password=", options: .caseInsensitive) else { return uri }
        return String(uri[..<range.lowerBound]) + "password=<redacted>"
    }

    /// Authorization / digest material must never reach a log site whole.
    static func redactAuthorizationHeader(_ header: String) -> String {
        guard let range = header.range(of: "response=", options: .caseInsensitive) else {
            return header.contains("Digest") || header.lowercased().contains("authorization")
                ? "<authorization redacted>" : header
        }
        return String(header[..<range.lowerBound]) + "response=<redacted>"
    }
}
