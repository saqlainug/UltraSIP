import SwiftUI

/// Compact header: registration indicator + account + controls.
struct StatusHeaderView: View {
    @ObservedObject var model: AppModel
    @Binding var showDiagnostics: Bool

    private var accountTitle: String {
        guard let account = model.account else { return "No account" }
        return account.label.isEmpty ? account.aor : account.label
    }

    private var statusColor: Color {
        switch model.registrationState {
        case .registered: .green
        case .registering: .yellow
        case .failed: .red
        case .unregistered: .gray
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(accountTitle)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(model.registrationState.userFacingDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Account \(model.account?.label ?? "none"), \(model.registrationState.userFacingDescription)")
            Spacer()
            Button {
                model.refreshRegistration()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Re-register now")
            .accessibilityLabel("Re-register")
            .disabled(model.account == nil)
            Button {
                showDiagnostics = true
            } label: {
                Image(systemName: "stethoscope")
            }
            .buttonStyle(.borderless)
            .help("Diagnostics")
            .accessibilityLabel("Diagnostics")
            Button {
                model.showAccountForm = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Account settings")
            .accessibilityLabel("Account settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
