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
                            Text(Format.time(slot, in: zone, use24Hour: use24Hour))
                                .font(.title3.monospacedDigit().weight(.medium))
                            let dayOffset = daysFromReference(zone)
                            Text(Format.shortDay(slot, in: zone) + (dayOffset > 0 ? " · next day" : dayOffset < 0 ? " · previous day" : ""))
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

    /// +1 when the slot falls on the next calendar day in `zone` than in
    /// the reference zone, -1 for the previous day.
    private func daysFromReference(_ zone: TimeZone) -> Int {
        let here = CivilDay(slot, in: zone)
        let there = CivilDay(slot, in: store.referenceZone)
        return here == there ? 0 : here < there ? -1 : 1
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
