import AppKit
import SwiftUI

/// The clicked hour, spelled out for every place, with a copy button for
/// pasting into an invite or chat.
struct SelectionSummary: View {
    let slot: Date
    let use24Hour: Bool

    @Environment(PlannerStore.self) private var store

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(store.orderedPlaces) { place in
                        let zone = place.timeZone
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Circle().fill(place.availability(at: slot).fill).frame(width: 8, height: 8)
                                Text(place.name).font(.caption.weight(.semibold))
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Format.time(slot, in: zone, use24Hour: use24Hour))
                                    .font(.title3.monospacedDigit().weight(.medium))
                                // On the day the clocks go back, this wall time
                                // happens twice: say which one.
                                if Timeline.wallTimeRepeats(in: zone, at: slot) {
                                    Text(Format.zoneAbbreviation(zone, at: slot))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                            }
                            let dayOffset = daysFromReference(zone)
                            Text(Format.shortDay(slot, in: zone) + Self.dayNote(dayOffset))
                                .font(.caption2.weight(dayOffset == 0 ? .regular : .bold))
                                .foregroundStyle(dayOffset == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                        }
                    }
                }
            }
            Spacer()
            Button("Copy", systemImage: "doc.on.doc", action: copy)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .help("Copy these times as text (⇧⌘C)")
            Button("Clear", systemImage: "xmark") { store.selectedSlot = nil }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
        }
    }

    /// Calendar days from the slot's date in the reference zone to its date
    /// in `zone`: +1 for the next day, -2 for two days earlier.
    private func daysFromReference(_ zone: TimeZone) -> Int {
        CivilDay(slot, in: store.referenceZone).days(to: CivilDay(slot, in: zone))
    }

    /// The note after a place's date: " · next day", " · 2 days earlier",
    /// or nothing on the reference day.
    nonisolated static func dayNote(_ offset: Int) -> String {
        switch offset {
        case 0: ""
        case 1: " · next day"
        case -1: " · previous day"
        case 2...: " · \(offset) days later"
        default: " · \(-offset) days earlier"
        }
    }

    private func copy() {
        let lines = store.orderedPlaces.map { place in
            let zone = place.timeZone
            let offset = Format.utcOffset(zone.secondsFromGMT(for: slot))
            return "\(place.name): \(Format.shortDay(slot, in: zone)), \(Format.time(slot, in: zone, use24Hour: use24Hour)) (\(offset))"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}
