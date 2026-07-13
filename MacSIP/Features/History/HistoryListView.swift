import SwiftUI

/// Milestone 1 history list (in-memory until the persistence slice).
/// Answered calls show talk duration; unanswered show their outcome
/// (SPEC §18 — never a meaningless 00:00).
struct HistoryListView: View {
    let entries: [CallHistoryEntry]

    var body: some View {
        Group {
            if entries.isEmpty {
                Text("No calls yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries) { entry in
                    HistoryRow(entry: entry)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: CallHistoryEntry

    private var directionSymbol: String {
        switch (entry.direction, entry.wasAnswered) {
        case (.incoming, true): "phone.arrow.down.left"
        case (.incoming, false): "phone.arrow.down.left"
        case (.outgoing, _): "phone.arrow.up.right"
        }
    }

    private var directionColor: Color {
        if !entry.wasAnswered, entry.direction == .incoming { return .red }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: directionSymbol)
                .font(.caption)
                .foregroundStyle(directionColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.remoteDisplayName.isEmpty ? entry.remoteURI : entry.remoteDisplayName)
                    .font(.caption)
                    .lineLimit(1)
                Text(entry.startedAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let talk = entry.talkDuration {
                Text(Self.format(talk))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.outcome)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.direction == .incoming ? "Incoming" : "Outgoing") call, \(entry.remoteDisplayName.isEmpty ? entry.remoteURI : entry.remoteDisplayName), \(entry.talkDuration.map { "duration \(Self.format($0))" } ?? entry.outcome)"
        )
    }

    private static func format(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
