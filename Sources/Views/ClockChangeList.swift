import SwiftUI

/// Daylight-saving changes near the shown day, one line per date and jump.
struct ClockChangeList: View {
    let changes: [ClockChange]
    let slots: [Date]
    let use24Hour: Bool

    @Environment(PlannerStore.self) private var store
    @AppStorage(SettingsKey.lookaheadDays) private var lookaheadDays = 14

    var body: some View {
        let groups = ClockChangeGroup.grouping(changes)
        VStack(alignment: .leading, spacing: 8) {
            if groups.isEmpty {
                Label("No clock changes for these places from today through \(lookaheadDays) days after the shown day.", systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Label(groups.count == 1 ? "1 clock change nearby" : "\(groups.count) clock changes nearby", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                ForEach(groups) { group in
                    row(group)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(groups.isEmpty ? Color.clear : Color.orange.opacity(0.08), in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(groups.isEmpty ? Color.secondary.opacity(0.2) : Color.orange.opacity(0.4)))
    }

    private func row(_ group: ClockChangeGroup) -> some View {
        let first = group.first
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(badge(first))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor(first).opacity(0.18), in: .capsule)
                .foregroundStyle(badgeColor(first))
                .frame(width: 96, alignment: .leading)

            Text(summary(group))
                .font(.callout.weight(.medium))
        }
        .help(group.changes.map(detail).joined(separator: "\n"))
    }

    /// "Sun, Nov 1 — New York, Denver: clocks go back 1 hour at 2:00 am local".
    /// A single zone also gets its offsets; a time is shown only when every
    /// zone in the group changes at the same local time.
    private func summary(_ group: ClockChangeGroup) -> String {
        let first = group.first
        var text = "\(Format.shortDay(first.date, in: first.timeZone)) — \(group.placeNames.formatted()): clocks go \(group.delta > 0 ? "forward" : "back") \(Format.duration(group.delta))"
        if let minute = group.localMinuteBefore {
            text += " at \(Format.time(minuteOfDay: minute, use24Hour: use24Hour)) local"
        }
        if group.changes.count == 1 {
            text += " (\(Format.utcOffset(first.offsetBefore)) → \(Format.utcOffset(first.offsetAfter)))"
        }
        return text
    }

    /// "Stockholm: 3:00 am local, UTC+2 → UTC+1".
    private func detail(_ change: ClockChange) -> String {
        "\(change.placeNames.formatted()): \(Format.time(minuteOfDay: change.localMinuteBefore, use24Hour: use24Hour)) local, \(Format.utcOffset(change.offsetBefore)) → \(Format.utcOffset(change.offsetAfter))"
    }

    private func badge(_ change: ClockChange) -> String {
        guard let first = slots.first, let last = slots.last else { return "" }
        if change.date < first { return "Before this day" }
        if change.date < last.addingTimeInterval(3600) { return "On this day" }
        let days = Calendar.gregorian(in: store.referenceZone).dateComponents([.day], from: first, to: change.date).day ?? 0
        return days <= 1 ? "Next day" : "In \(days) days"
    }

    private func badgeColor(_ change: ClockChange) -> Color {
        guard let first = slots.first, let last = slots.last else { return .secondary }
        if change.date < first { return .secondary }
        if change.date < last.addingTimeInterval(3600) { return .red }
        return .orange
    }
}
