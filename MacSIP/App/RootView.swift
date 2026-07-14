import SwiftUI

/// Milestone 1 shell: status header, dialer, live calls, history.
/// Compact-window AppKit chrome arrives with Milestone 3 (approval gate 2).
struct RootView: View {
    @StateObject private var model = AppModel()
    @State private var showDiagnostics = false

    var body: some View {
        VStack(spacing: 0) {
            StatusHeaderView(model: model, showDiagnostics: $showDiagnostics)
            Divider()
            switch model.engineStatus {
            case .failed(let message):
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                    Text("SIP engine failed to start")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await model.startEngine() } }
                }
                .padding(20)
                Spacer()
            case .stopped, .starting:
                Spacer()
                ProgressView("Starting SIP engine…")
                Spacer()
            case .running:
                if model.accounts.isEmpty {
                    ScrollView { AccountFormView(model: model, editingAccount: nil, onCancel: nil) }
                } else {
                    mainContent
                }
            }
        }
        .frame(width: 360, height: 560)
        .task { await model.startEngine() }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView(model: model)
        }
        .sheet(isPresented: $model.showAccountForm) {
            AccountsListView(model: model)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 10) {
            ForEach(model.incomingCalls) { snapshot in
                IncomingCallBanner(model: model, snapshot: snapshot)
            }
            ForEach(model.activeCalls) { snapshot in
                ActiveCallView(model: model, snapshot: snapshot)
            }
            DialerView(model: model)
            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .accessibilityLabel("Error: \(error)")
            }
            HistoryListView(entries: model.history)
        }
        .padding(.top, 10)
    }
}

#Preview {
    RootView()
}
