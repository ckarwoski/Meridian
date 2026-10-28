import SwiftUI

/// The left-hand label of a row. Clicking it opens the place's settings.
struct PlaceLabel: View {
    let place: Place
    let isReference: Bool
    let now: Date
    let use24Hour: Bool

    @Environment(PlannerStore.self) private var store
    @State private var isEditing = false

    var body: some View {
        Button { isEditing = true } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if store.order == .manual {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .help("Drag to reorder")
                    }
                    Text(place.name).font(.callout.weight(.semibold))
                    if isReference {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help("Reference: the grid shows this place's hours")
                    }
                }
                if !place.note.isEmpty {
                    Text(place.note).font(.caption).foregroundStyle(.secondary)
                }
                Text(statusLine)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("\(place.name) — \(place.detail)\n\(place.timeZoneID)")
        .popover(isPresented: $isEditing, arrowEdge: .trailing) {
            PlaceEditor(placeID: place.id)
                .environment(store)
        }
    }

    /// "+6h · now 14:05", using the gap on the shown day (which may differ
    /// from today's if the clocks change in between).
    private var statusLine: String {
        let zone = place.timeZone
        let current = "now " + Format.time(now, in: zone, use24Hour: use24Hour)
        if isReference { return "\(Format.utcOffset(zone.secondsFromGMT(for: now))) · \(current)" }
        let onShownDay = store.day.noon(in: store.referenceZone)
        let gap = zone.secondsFromGMT(for: onShownDay) - store.referenceZone.secondsFromGMT(for: onShownDay)
        return "\(Format.offset(gap)) · \(current)"
    }
}

private struct PlaceEditor: View {
    let placeID: Place.ID

    @Environment(PlannerStore.self) private var store
    @AppStorage(SettingsKey.use24Hour) private var use24Hour = Format.localePrefers24Hour

    var body: some View {
        if let place = store.place(id: placeID) {
            let binding = Binding(get: { store.place(id: placeID) ?? place }, set: { store.update($0) })
            let ordered = store.orderedPlaces
            let index = ordered.firstIndex { $0.id == placeID } ?? 0
            Form {
                Section {
                    TextField("Name", text: binding.name)
                    TextField("Note", text: binding.note, prompt: Text("Who's here, e.g. Priya and Tom"))
                    LabeledContent("Location", value: place.detail)
                    LabeledContent("Time zone", value: place.timeZoneID)
                }
                Section("Working hours") {
                    Picker("Start", selection: binding.workStart) { halfHourOptions }
                    Picker("End", selection: binding.workEnd) { halfHourOptions }
                }
                Section {
                    HStack {
                        Button("Make Reference") { store.makeReference(id: placeID) }
                            .disabled(placeID == store.referenceID)
                            .help("Show the grid in this place's hours")
                        Spacer()
                        if store.order == .manual {
                            Button { store.move(id: placeID, by: -1) } label: { Image(systemName: "arrow.up") }
                                .disabled(index == 0)
                                .help("Move up")
                            Button { store.move(id: placeID, by: 1) } label: { Image(systemName: "arrow.down") }
                                .disabled(index == ordered.count - 1)
                                .help("Move down")
                        }
                        Button("Remove", role: .destructive) { store.remove(id: placeID) }
                            .disabled(store.places.count == 1)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 360)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var halfHourOptions: some View {
        ForEach(Array(stride(from: 0, to: 1440, by: 30)), id: \.self) { minute in
            Text(Format.time(minuteOfDay: minute, use24Hour: use24Hour)).tag(minute)
        }
    }
}
