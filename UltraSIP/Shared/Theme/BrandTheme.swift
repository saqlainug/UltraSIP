import AppKit
import SwiftUI

/// The Ultranet brand palette — the single source of truth for colour in the
/// app. Views reference the semantic tokens below, never raw hex or system
/// colours, so a brand refresh is a one-file change (SPEC: identity must be
/// configurable, never scattered through source).
///
/// Source values are taken from Ultranet's own brand palette:
///   blue `#176FA6` · deep blue `#06619B` · orange `#F2A71B` · ink `#050F18`
/// and live in `Resources/Assets.xcassets` with light **and** dark variants.
///
/// Contrast (WCAG 2.1, measured against the window background):
///   blue 5.44:1 light / 6.84:1 dark — passes AA for text.
///   The vivid brand orange is only 2.04:1 on white, so it is used **as a
///   fill** (dark ink on orange = 9.48:1) and never as light-mode text or
///   strokes; `brandOrangeInk` (4.99:1 light) carries orange into text,
///   icons and borders. Do not swap the two.
nonisolated enum BrandColor {
    /// Primary brand blue. Accent, primary actions, registered/healthy state.
    static let blue = Color("BrandBlue")
    /// Deeper blue for emphasis, headers and pressed states.
    static let blueDeep = Color("BrandBlueDeep")
    /// Vivid brand orange — FILLS AND BADGES ONLY (see contrast note above).
    static let orange = Color("BrandOrange")
    /// Contrast-safe orange for text, icons and strokes in both appearances.
    static let orangeInk = Color("BrandOrangeInk")

    // AppKit equivalents for the non-SwiftUI chrome (menu bar, panels).
    static let blueNS = NSColor(named: "BrandBlue") ?? .controlAccentColor
    static let orangeNS = NSColor(named: "BrandOrange") ?? .systemOrange
    static let orangeInkNS = NSColor(named: "BrandOrangeInk") ?? .systemOrange
}

/// Semantic roles. Views use these, not the raw colours — so "what it means"
/// stays separate from "what it looks like".
nonisolated enum BrandRole {
    /// Primary affirmative action: place call, answer.
    static let primaryAction = BrandColor.blue
    /// Destructive action: hang up, decline. Deliberately NOT brand-coloured —
    /// red for danger is a safety affordance, not a style choice.
    static let destructiveAction = Color.red
    /// Attention / in-progress: ringing, connecting, warnings.
    static let attention = BrandColor.orangeInk
    /// Attention as a background wash (incoming-call banner, badges).
    static let attentionFill = BrandColor.orange
    /// Healthy, connected, secure.
    static let positive = BrandColor.blue
    /// Idle / unregistered — no colour, just de-emphasis.
    static let idle = Color.secondary
}
