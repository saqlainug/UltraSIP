import SwiftUI

/// One in-progress call: identity, live state/duration, and controls
/// (mute, hold, DTMF keypad, hang up).
struct ActiveCallView: View {
    @ObservedObject var model: AppModel
    let snapshot: CallSnapshot
    @State private var showKeypad = false

    private var isConnected: Bool { snapshot.state.isConnected }
    private var isHeldLocally: Bool {
        if case .connected(let hold) = snapshot.state { return hold == .local || hold == .both }
        return false
    }

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(snapshot.remoteDisplayName.isEmpty ? snapshot.remoteURI : snapshot.remoteDisplayName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if !snapshot.remoteDisplayName.isEmpty {
                    Text(snapshot.remoteURI)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 6) {
                        Text(snapshot.state.userFacingDescription)
                        if let talk = snapshot.talkDuration(now: context.date) {
                            Text(Self.format(talk)).monospacedDigit()
                        }
                        if snapshot.mediaActive {
                            Image(systemName: "waveform")
                                .accessibilityLabel("Audio active")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 10) {
                Button {
                    model.toggleMute(snapshot.id)
                } label: {
                    Image(systemName: snapshot.muted ? "mic.slash.fill" : "mic.fill")
                }
                .help(snapshot.muted ? "Unmute" : "Mute")
                .accessibilityLabel(snapshot.muted ? "Unmute microphone" : "Mute microphone")
                .disabled(!isConnected)

                Button {
                    model.toggleHold(snapshot.id)
                } label: {
                    Image(systemName: isHeldLocally ? "play.fill" : "pause.fill")
                }
                .help(isHeldLocally ? "Resume" : "Hold")
                .accessibilityLabel(isHeldLocally ? "Resume call" : "Hold call")
                .disabled(!isConnected)

                Button {
                    showKeypad.toggle()
                } label: {
                    Image(systemName: "circle.grid.3x3.fill")
                }
                .help("DTMF keypad")
                .accessibilityLabel("Show DTMF keypad")
                .disabled(!isConnected)

                Spacer()

                Button(role: .destructive) {
                    model.hangup(snapshot.id)
                } label: {
                    Image(systemName: "phone.down.fill")
                }
                .keyboardShortcut(.escape, modifiers: [])
                .help("Hang up")
                .accessibilityLabel("Hang up")
            }
            .buttonStyle(.bordered)

            if showKeypad, isConnected {
                DTMFKeypad { digit in
                    model.sendDTMF(digit, to: snapshot.id)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
        .padding(.horizontal, 12)
    }

    private static func format(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// 3×4 DTMF grid. Digits are sensitive (may carry PINs) — they are sent,
/// never logged (LogRedactor).
struct DTMFKeypad: View {
    let onDigit: (String) -> Void
    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["*", "0", "#"]]

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { digit in
                        Button(digit) { onDigit(digit) }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
                            .accessibilityLabel("DTMF \(digit)")
                    }
                }
            }
        }
    }
}
