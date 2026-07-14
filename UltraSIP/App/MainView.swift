import SwiftUI

/// Main window content (docs/UI_LAYOUT_SPEC.md): header · tab bar ·
/// content · status footer, with live-call cards inserted above the tabs.
struct MainView: View {
    @ObservedObject var model: AppModel

    enum Tab: Int, CaseIterable {
        case dialpad, calls, contacts

        var title: String {
            switch self {
            case .dialpad: "Dialpad"
            case .calls: "Calls"
            case .contacts: "Contacts"
            }
        }
    }

    @State private var tab: Tab = .dialpad
    @State private var showDiagnostics = false

    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderView(model: model, showDiagnostics: $showDiagnostics)
            Divider()

            switch model.engineStatus {
            case .failed(let message):
                engineFailure(message)
            case .stopped, .starting:
                Spacer()
                ProgressView("Starting SIP engine…")
                Spacer()
            case .running:
                if model.accounts.isEmpty {
                    ScrollView {
                        AccountFormView(model: model, editingAccount: nil, onCancel: nil)
                    }
                } else {
                    activeContent
                }
            }

            Divider()
            StatusFooterView(model: model)
        }
        .frame(minWidth: 340, maxWidth: 380, minHeight: 520, maxHeight: 620)
        .task { await model.startEngine() }
        .sheet(isPresented: $showDiagnostics) { DiagnosticsView(model: model) }
        .sheet(isPresented: $model.showAccountForm) { AccountsListView(model: model) }
    }

    private var activeContent: some View {
        VStack(spacing: 8) {
            // Live calls sit above the tabs so they are always visible.
            if !model.incomingCalls.isEmpty || !model.activeCalls.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(model.incomingCalls) { snapshot in
                            IncomingCallBanner(model: model, snapshot: snapshot)
                        }
                        ForEach(model.activeCalls) { snapshot in
                            ActiveCallView(model: model, snapshot: snapshot)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxHeight: 240)
                Divider()
            }

            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.top, model.incomingCalls.isEmpty && model.activeCalls.isEmpty ? 8 : 0)
            .accessibilityLabel("Section")

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .accessibilityLabel("Error: \(error)")
            }

            switch tab {
            case .dialpad:
                DialerView(model: model)
            case .calls:
                HistoryListView(model: model)
            case .contacts:
                ContactsPlaceholderView()
            }
        }
        // Keyboard: ⌘1/⌘2/⌘3 switch tabs (hidden buttons carry the
        // shortcuts; the segmented control stays the visible affordance).
        .background {
            VStack {
                Button("") { tab = .dialpad }.keyboardShortcut("1", modifiers: .command)
                Button("") { tab = .calls }.keyboardShortcut("2", modifiers: .command)
                Button("") { tab = .contacts }.keyboardShortcut("3", modifiers: .command)
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
    }

    private func engineFailure(_ message: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text("SIP engine failed to start").font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await model.startEngine() } }
            Spacer()
        }
        .padding(20)
    }
}

/// Contacts tab exists from M3 (spec) but is functional at M5 — the empty
/// state says so rather than implying a working feature.
struct ContactsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "person.2")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("Contacts")
                .font(.callout.weight(.medium))
            Text("Contact management arrives in a later milestone.\nDial numbers and SIP addresses from the Dialpad.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Contacts. Contact management arrives in a later milestone.")
    }
}
