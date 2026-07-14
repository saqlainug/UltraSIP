import SwiftUI

/// Dialpad tab (docs/UI_LAYOUT_SPEC.md): destination field, 3×4 keypad,
/// call / redial / voicemail row. Keypad digits type into the field, or —
/// when a call is connected — send DTMF instead.
struct DialerView: View {
    @ObservedObject var model: AppModel
    @State private var input = ""
    @FocusState private var fieldFocused: Bool

    private var connectedCall: CallSnapshot? {
        model.activeCalls.first { $0.state.isConnected }
    }

    private var canCall: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty && model.account != nil
    }

    private var hasVoicemail: Bool {
        model.account?.voicemailNumber.isEmpty == false
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("Number or SIP address", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onSubmit { if canCall { placeCall() } }
                    .accessibilityLabel("Number or SIP address to call")
                Button {
                    if !input.isEmpty { input.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                }
                .buttonStyle(.borderless)
                .disabled(input.isEmpty)
                .help("Backspace")
                .accessibilityLabel("Backspace")
            }
            .padding(.horizontal, 12)

            if connectedCall != nil {
                Text("Keypad sends DTMF during the call")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Keypad { key in
                if let call = connectedCall {
                    model.sendDTMF(key, to: call.id)
                } else {
                    input.append(key)
                }
            }
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Button {
                    placeCall()
                } label: {
                    Label("Call", systemImage: "phone.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandRole.primaryAction)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!canCall)
                .accessibilityLabel("Place audio call")

                Button {
                    Task { await model.redial() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .disabled(model.lastDialedNumber?.isEmpty != false || model.account == nil)
                .help(model.lastDialedNumber.map { "Redial \($0)" } ?? "Redial")
                .accessibilityLabel("Redial last number")

                if hasVoicemail {
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
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .onAppear { fieldFocused = true }
        // ⌘L focuses the destination field (spec keyboard map).
        .background {
            Button("") { fieldFocused = true }
                .keyboardShortcut("l", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private func placeCall() {
        let destination = input
        Task {
            await model.dial(destination)
            if model.lastError == nil { input = "" }
        }
    }
}

/// 3×4 keypad. Keys are 44 pt tall per the layout spec; digit + letters
/// sublabel, matching a phone keypad.
struct Keypad: View {
    let onKey: (String) -> Void

    private struct Key: Hashable {
        let digit: String
        let letters: String
    }

    private let rows: [[Key]] = [
        [Key(digit: "1", letters: ""), Key(digit: "2", letters: "ABC"), Key(digit: "3", letters: "DEF")],
        [Key(digit: "4", letters: "GHI"), Key(digit: "5", letters: "JKL"), Key(digit: "6", letters: "MNO")],
        [Key(digit: "7", letters: "PQRS"), Key(digit: "8", letters: "TUV"), Key(digit: "9", letters: "WXYZ")],
        [Key(digit: "*", letters: ""), Key(digit: "0", letters: "+"), Key(digit: "#", letters: "")],
    ]

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        Button {
                            onKey(key.digit)
                        } label: {
                            VStack(spacing: 0) {
                                Text(key.digit)
                                    .font(.system(size: 16, weight: .medium))
                                if !key.letters.isEmpty {
                                    Text(key.letters)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(accessibilityLabel(for: key.digit))
                    }
                }
            }
        }
    }

    private func accessibilityLabel(for digit: String) -> String {
        switch digit {
        case "*": "Star"
        case "#": "Pound"
        default: digit
        }
    }
}
