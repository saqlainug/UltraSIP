/// User-facing mapping of final SIP status codes, per SPEC §4
/// ("Incoming and outgoing calls"). The raw SIP code must always remain
/// available in diagnostics; this mapping is display text only.
nonisolated enum SIPStatusMapping {
    /// Returns the user-facing result text for a final SIP status code.
    /// Codes without a spec-mandated mapping fall back to a generic result
    /// that still surfaces the numeric code instead of hiding it.
    static func userFacingResult(forStatusCode code: Int) -> String {
        switch code {
        case 400: "Invalid request"
        case 401: "Authentication required"
        case 403: "Call forbidden"
        case 404: "Number not found"
        case 407: "Proxy authentication required"
        case 408: "Request timed out"
        case 480: "Temporarily unavailable"
        case 481: "Call no longer exists"
        case 486: "Busy"
        case 487: "Call cancelled"
        case 488: "Incompatible media"
        case 500: "Server error"
        case 502: "Bad gateway"
        case 503: "Service unavailable"
        case 600: "Busy"
        case 603: "Call declined"
        default: "Call failed (\(code))"
        }
    }
}
