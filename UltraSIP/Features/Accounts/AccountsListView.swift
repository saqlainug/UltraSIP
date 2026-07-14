import SwiftUI

/// Account management sheet: stored accounts, the active one marked,
/// activate/edit/delete + add (SPEC §1: multiple accounts, one active,
/// switch without restart).
struct AccountsListView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private enum Mode: Equatable {
        case list
        case adding
        case editing(UUID)
    }

    @State private var mode: Mode = .list

    var body: some View {
        Group {
            switch mode {
            case .list:
                listContent
            case .adding:
                ScrollView {
                    AccountFormView(model: model, editingAccount: nil) { mode = .list }
                }
            case .editing(let id):
                ScrollView {
                    AccountFormView(
                        model: model,
                        editingAccount: model.accounts.first { $0.id == id }
                    ) { mode = .list }
                }
            }
        }
        .frame(width: 340, height: 420)
        .onChange(of: model.showAccountForm) { shown in
            // saveAccount dismisses by clearing the flag.
            if !shown { mode = .list }
        }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SIP Accounts").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            if model.accounts.isEmpty {
                Spacer()
                Text("No accounts yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(model.accounts) { account in
                    HStack(spacing: 8) {
                        Image(
                            systemName: account.id == model.activeAccountID
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundStyle(account.id == model.activeAccountID ? .green : .secondary)
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(account.label.isEmpty ? account.aor : account.label)
                                .font(.callout)
                                .lineLimit(1)
                            Text("\(account.username)@\(account.domain) · \(account.transport.rawValue.uppercased())")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if account.id != model.activeAccountID {
                            Button("Activate") {
                                Task { await model.switchAccount(to: account.id) }
                            }
                            .controlSize(.small)
                        }
                        Button {
                            mode = .editing(account.id)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .controlSize(.small)
                        .accessibilityLabel("Edit \(account.label.isEmpty ? account.aor : account.label)")
                        Button(role: .destructive) {
                            Task { await model.deleteAccount(id: account.id) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .controlSize(.small)
                        .accessibilityLabel("Delete \(account.label.isEmpty ? account.aor : account.label)")
                    }
                    .accessibilityElement(children: .contain)
                }
                .listStyle(.plain)
            }
            if let error = model.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Button {
                mode = .adding
            } label: {
                Label("Add Account", systemImage: "plus")
            }
        }
        .padding(14)
    }
}
