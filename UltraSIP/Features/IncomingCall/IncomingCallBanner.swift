import SwiftUI

/// Milestone 1 incoming-call prompt, shown inside the main window. The
/// floating cross-Spaces NSPanel arrives with Milestone 3 (approval gate 2).
struct IncomingCallBanner: View {
    @ObservedObject var model: AppModel
    let snapshot: CallSnapshot

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "phone.arrow.down.left")
                    .foregroundStyle(BrandRole.attention)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.remoteDisplayName.isEmpty ? snapshot.remoteURI : snapshot.remoteDisplayName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text("Incoming call")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Button {
                    model.answer(snapshot.id)
                } label: {
                    Label("Answer", systemImage: "phone.fill")
                }
                .tint(BrandRole.primaryAction)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityLabel("Answer call")

                Button {
                    model.reject(snapshot.id, busy: true)
                } label: {
                    Text("Busy")
                }
                .accessibilityLabel("Reject as busy")

                Button(role: .destructive) {
                    model.reject(snapshot.id, busy: false)
                } label: {
                    Label("Decline", systemImage: "phone.down.fill")
                }
                .keyboardShortcut(.escape, modifiers: [])
                .accessibilityLabel("Decline call")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(BrandRole.attentionFill.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(BrandRole.attention.opacity(0.5)))
        .padding(.horizontal, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Incoming call from \(snapshot.remoteDisplayName.isEmpty ? snapshot.remoteURI : snapshot.remoteDisplayName)"
        )
    }
}
