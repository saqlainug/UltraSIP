import SwiftUI

/// Milestone 1 diagnostics: sanitized engine snapshot (versions, transport,
/// codecs, registration). Never contains credentials (bridge contract).
struct DiagnosticsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var info = "Loading…"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Diagnostics").font(.headline)
                Spacer()
                Button("Refresh") { Task { info = await model.diagnostics() } }
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            ScrollView {
                Text(info)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .frame(width: 340, height: 380)
        .task { info = await model.diagnostics() }
    }
}
