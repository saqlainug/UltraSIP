import SwiftUI

/// Calls tab (docs/UI_LAYOUT_SPEC.md): searchable, date-grouped history.
/// Answered calls show talk duration; unanswered show their outcome
/// (SPEC §18 — never a meaningless 00:00). Double-click / ↩ redials.
struct HistoryListView: View {
    @ObservedObject var model: AppModel
    @State private var search = ""
    @State private var selection: CallHistoryEntry.ID?
    @FocusState private var searchFocused: Bool

    private var filtered: [CallHistoryEntry] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return model.history }
        return model.history.filter {
            $0.remoteURI.lowercased().contains(query)
                || $0.remoteDisplayName.lowercased().contains(query)
        }
    }

    /// Groups: Today / Yesterday / date, newest first.
    private var groups: [(title: String, entries: [CallHistoryEntry])] {
        let calendar = Calendar.current
        var order: [String] = []
        var buckets: [String: [CallHistoryEntry]] = [:]
        for entry in filtered {
            let title: String
            if calendar.isDateInToday(entry.startedAt) {
                title = "Today"
            } else if calendar.isDateInYesterday(entry.startedAt) {
                title = "Yesterday"
            } else {
                title = entry.startedAt.formatted(.dateTime.month(.abbreviated).day().year())
            }
            if buckets[title] == nil {
                buckets[title] = []
                order.append(title)
            }
            buckets[title]?.append(entry)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search calls", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .focused($searchFocused)
                    .accessibilityLabel("Search call history")
            }
            .padding(.horizontal, 12)

            if model.history.isEmpty {
                Spacer()
                Text("No calls yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                Text("No calls match “\(search)”")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(selection: $selection) {
                    ForEach(groups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.entries) { entry in
                                HistoryRow(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) { redial(entry) }
                                    .contextMenu {
                                        Button("Call") { redial(entry) }
                                        Button("Copy") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(entry.remoteURI, forType: .string)
                                        }
                                        Divider()
                                        Button("Delete", role: .destructive) {
                                            Task { await model.deleteHistoryEntry(entry.id) }
                                        }
                                    }
                                    .tag(entry.id)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                HStack {
                    Spacer()
                    Button("Clear History…") { Task { await model.clearHistory() } }
                        .controlSize(.small)
                        .accessibilityLabel("Clear call history")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 6)
        .background {
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private func redial(_ entry: CallHistoryEntry) {
        Task { await model.dial(entry.remoteURI) }
    }
}

private struct HistoryRow: View {
    let entry: CallHistoryEntry

    private var directionSymbol: String {
        entry.direction == .incoming ? "phone.arrow.down.left" : "phone.arrow.up.right"
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
        .padding(.vertical, 2)
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
