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
        if model.isDirectDialing {
            return model.directDialingReady ? .green : .gray
        }
        switch model.registrationState {
        case .registered: return .green
        case .registering: return .yellow
        case .failed: return .red
        case .unregistered: return .gray
        }
    }

    /// Direct-dialing accounts show availability, not registration
    /// (MicroSIP local-account parity).
    private var statusText: String {
        if model.isDirectDialing {
            return model.directDialingReady ? "Ready — direct dialing" : "Engine starting…"
        }
        return model.registrationState.userFacingDescription
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
            // Account selector (SPEC main-window header): quick switch
            // between stored accounts; management via the gear.
            Menu {
                ForEach(model.accounts) { account in
                    Button {
                        Task { await model.switchAccount(to: account.id) }
                    } label: {
                        HStack {
                            Text(account.label.isEmpty ? account.aor : account.label)
                            if account.id == model.activeAccountID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button("Manage Accounts…") { model.showAccountForm = true }
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(accountTitle)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel(
                "Account \(model.account?.label ?? "none"), \(statusText). Switch account"
            )
            Spacer()
            Button {
                model.refreshRegistration()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Re-register now")
            .accessibilityLabel("Re-register")
            // Meaningless for a non-registering account (honesty rule).
            .disabled(model.account == nil || model.isDirectDialing)
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
