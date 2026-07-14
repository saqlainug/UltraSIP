import SwiftUI

/// Milestone 1 dialer: destination field + call action. The 3×4 dialpad UI
/// arrives with the Milestone 3 layout spec (approval gate 2).
struct DialerView: View {
    @ObservedObject var model: AppModel
    @State private var input = ""
    @FocusState private var fieldFocused: Bool

    private var canCall: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty && model.account != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Number or SIP address", text: $input)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit { if canCall { placeCall() } }
                .accessibilityLabel("Number or SIP address to call")
            Button {
                placeCall()
            } label: {
                Label("Call", systemImage: "phone.fill")
                    .labelStyle(.titleAndIcon)
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!canCall)
            .accessibilityLabel("Place audio call")
            if model.account?.voicemailNumber.isEmpty == false {
                Button {
                    Task { await model.dialVoicemail() }
                } label: {
                    Image(systemName: "envelope.fill")
                }
                .help("Call voicemail")
                .accessibilityLabel("Call voicemail")
            }
        }
        .padding(.horizontal, 12)
    }

    private func placeCall() {
        let destination = input
        Task {
            await model.dial(destination)
            if model.lastError == nil { input = "" }
        }
    }
}
