import SwiftUI

/// Milestone 0 shell view. No SIP functionality exists yet; this view states
/// the real project status so the build is never mistaken for a working phone.
struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "phone")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("MacSIP")
                .font(.headline)
            Text(
                "Milestone 0 — project foundation.\nThe SIP engine is not integrated yet; this build cannot place or receive calls."
            )
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 360, height: 560)
    }
}

#Preview {
    RootView()
}
