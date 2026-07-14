import Foundation

/// Registration lifecycle per docs/SIP_STATE_MACHINES.md ("Registration").
nonisolated enum RegistrationState: Equatable, Sendable {
    case unregistered
    case registering
    case registered(expiresAt: Date?)
    case failed(code: Int?, reason: String)

    /// Whether `self → next` is a legal transition per the state machine.
    func canTransition(to next: RegistrationState) -> Bool {
        switch (self, next) {
        case (.unregistered, .registering),
            (.registering, .registered),
            (.registering, .failed),
            (.registered, .registering),
            (.registered, .unregistered),
            (.failed, .registering),
            (.failed, .unregistered):
            true
        // Refresh results may arrive while already registered; a repeat of
        // the same phase is not a machine violation, just an update.
        case (.registered, .registered), (.registering, .registering),
            (.failed, .failed), (.unregistered, .unregistered):
            true
        // Engine stop can force-unregister from any state.
        case (_, .unregistered):
            true
        default:
            false
        }
    }

    /// Short user-facing status text. Raw code preserved separately for
    /// diagnostics; 401/403/404 wording comes from SIPStatusMapping.
    var userFacingDescription: String {
        switch self {
        case .unregistered: "Not registered"
        case .registering: "Registering…"
        case .registered: "Registered"
        case .failed(let code, let reason):
            if let code {
                "Registration failed: \(SIPStatusMapping.userFacingResult(forStatusCode: code))"
            } else {
                "Registration failed: \(reason)"
            }
        }
    }
}
