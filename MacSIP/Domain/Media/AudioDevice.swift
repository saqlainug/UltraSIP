import Foundation

/// An audio device as reported by the SIP media stack.
/// `systemDefaultIndex` (-1) means "follow the system default device".
nonisolated struct AudioDevice: Identifiable, Equatable, Sendable {
    static let systemDefaultIndex = -1

    let index: Int
    let name: String
    let isInput: Bool
    let isOutput: Bool

    var id: Int { index }
}
