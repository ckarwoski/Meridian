import SwiftUI

extension Availability {
    var fill: Color {
        switch self {
        case .working: .green.opacity(0.55)
        case .shoulder: .yellow.opacity(0.4)
        case .night: .indigo.opacity(0.14)
        }
    }
}

/// One row per place, one column per hour of the shown day in the reference
/// zone. Hovering a column lines it up across every row; clicking selects it.
struct PlannerGrid: View {
    let slots: [Date]
    let now: Date
    let use24Hour: Bool

    @Environment(PlannerStore.self) private var store
    @State private var hovered: Int?
    @State private var dropTarget: Place.ID?
    @AppStorage(SettingsKey.showDaylight) private var showDaylight = true

    static let labelWidth: CGFloat = 220
    static let rowHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            nowMarkers
            ForEach(store.orderedPlaces) { place in
                row {
                    PlaceLabel(place: place, isReference: place.id == store.referenceID, now: now, use24Hour: use24Hour)
                } cells: { i in
                    HourCell(place: place, slot: slots[i], isFirst: i == 0, use24Hour: use24Hour, showDaylight: showDaylight)
                }
                .modifier(Reorderable(place: place, enabled: store.order == .manual, dropTarget: $dropTarget))
            }
            row {
                Text("Overlap")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } cells: { i in
                OverlapCell(places: store.places, slot: slots[i])
            }
            .padding(.top, 4)
        }
    }

    /// A row with a fixed-width label and a cell per slot. Every row uses
    /// the same layout, so column i lines up from top to bottom.
    private func row<Label: View, Cell: View>(
        @ViewBuilder label: () -> Label,
        @ViewBuilder cells: @escaping (Int) -> Cell
    ) -> some View {
        HStack(spacing: 8) {
            label().frame(width: Self.labelWidth, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(slots.indices, id: \.self) { i in
                    cells(i)
                        .frame(maxWidth: .infinity, minHeight: Self.rowHeight, maxHeight: Self.rowHeight)
                        .overlay { columnHighlight(i) }
                        .contentShape(.rect)
                        .onHover { inside in
                            if inside { hovered = i } else if hovered == i { hovered = nil }
                        }
                        .onTapGesture { toggleSelection(slots[i]) }
                }
            }
        }
    }

    private var nowMarkers: some View {
        HStack(spacing: 8) {
            Picker("Order", selection: Binding(get: { store.order }, set: { store.setOrder($0) })) {
                ForEach(PlaceOrder.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .fixedSize()
            .help("West → East keeps the earliest local time at the top. Manual lets you drag places into your own order.")
            .frame(width: Self.labelWidth, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(slots.indices, id: \.self) { i in
                    ZStack {
                        if slots[i] <= now && now < slots[i].addingTimeInterval(3600) {
                            Text("NOW")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .background(.red, in: .capsule)
                                .fixedSize()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func columnHighlight(_ i: Int) -> some View {
        let isSelected = store.selectedSlot == slots[i]
        let isNow = slots[i] <= now && now < slots[i].addingTimeInterval(3600)
        if isSelected {
            RoundedRectangle(cornerRadius: 5).strokeBorder(Color.accentColor, lineWidth: 2.5)
        } else if hovered == i {
            RoundedRectangle(cornerRadius: 5).fill(.primary.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.35), lineWidth: 1))
        } else if isNow {
            RoundedRectangle(cornerRadius: 5).strokeBorder(.red.opacity(0.6), lineWidth: 1)
        }
    }

    private func toggleSelection(_ slot: Date) {
        store.selectedSlot = store.selectedSlot == slot ? nil : slot
    }
}

/// In manual order, a row can be dragged onto another row to take its place.
private struct Reorderable: ViewModifier {
    let place: Place
    let enabled: Bool
    @Binding var dropTarget: Place.ID?

    @Environment(PlannerStore.self) private var store

    func body(content: Content) -> some View {
        if enabled {
            content
                .draggable(place.id.uuidString) {
                    Text(place.name)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: .rect(cornerRadius: 6))
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let moved = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                    withAnimation(.snappy) { store.move(id: moved, onto: place.id) }
                    return true
                } isTargeted: { targeted in
                    if targeted { dropTarget = place.id } else if dropTarget == place.id { dropTarget = nil }
                }
                .overlay(alignment: .top) {
                    if dropTarget == place.id {
                        Rectangle().fill(Color.accentColor).frame(height: 2).offset(y: -3)
                    }
                }
        } else {
            content
        }
    }
}

private struct HourCell: View {
    let place: Place
    let slot: Date
    let isFirst: Bool
    let use24Hour: Bool
    let showDaylight: Bool

    var body: some View {
        let zone = place.timeZone
        let label = Format.cellHour(slot, in: zone, use24Hour: use24Hour)
        let isMidnight = place.localMinuteOfDay(at: slot) < 60
        // A jump on this cell's left edge, or on its right edge. Hour cells
        // on either side of a jump are labelled with their zone's
        // abbreviation, so a repeated hour reads "1a MDT", "1a MST".
        let jumpBefore = Timeline.jump(in: zone, at: slot)
        let jumpAfter = Timeline.jump(in: zone, at: slot.addingTimeInterval(3600))
        let clocksChangeInside = Timeline.clocksChange(in: zone, duringHourStarting: slot)
        let availability = place.availability(at: slot)
        let daylight = showDaylight ? place.daylight(at: slot.addingTimeInterval(1800)) : nil
        let explanation = jumpExplanation(before: jumpBefore, after: jumpAfter, zone: zone)

        RoundedRectangle(cornerRadius: 5)
            .fill(availability.fill)
            .overlay {
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(label.hour)
                            .font(.system(.callout, design: .rounded).weight(availability == .working ? .semibold : .regular))
                        if let minute = label.minute {
                            Text(minute).font(.system(size: 8))
                        }
                    }
                    if let detail = detailLine(zone: zone, showDay: isMidnight || isFirst, showZone: jumpBefore != nil || jumpAfter != nil) {
                        // The day marks where each row's local date starts,
                        // since it may differ from the reference date.
                        Text(detail)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(jumpBefore != nil || jumpAfter != nil ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(availability == .night ? .secondary : .primary)
                .padding(.bottom, daylight == nil ? 0 : 2)
            }
            .overlay(alignment: .bottom) {
                if let daylight {
                    daylight.fill.frame(height: 3)
                }
            }
            .clipShape(.rect(cornerRadius: 5))
            .overlay(alignment: .leading) {
                if let jumpBefore {
                    // Solid: an hour is about to repeat. Dashed: an hour was
                    // skipped, so the wall clock has a gap here.
                    VerticalLine()
                        .stroke(.orange, style: StrokeStyle(lineWidth: 2.5, dash: jumpBefore.isForward ? [3, 2] : []))
                        .frame(width: 2.5)
                        .offset(x: -2.25)
                } else if isMidnight && !isFirst {
                    Rectangle().fill(.primary.opacity(0.5)).frame(width: 1.5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if clocksChangeInside {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .padding(2)
                }
            }
            .help(tooltip(zone: zone, clocksChangeInside: clocksChangeInside, daylight: daylight, explanation: explanation))
            .accessibilityElement()
            .accessibilityLabel(tooltip(zone: zone, clocksChangeInside: clocksChangeInside, daylight: daylight, explanation: explanation))
    }

    /// "Sun 1", "MDT", or "Sun 1 · MDT".
    private func detailLine(zone: TimeZone, showDay: Bool, showZone: Bool) -> String? {
        var parts: [String] = []
        if showDay { parts.append(slot.formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated).day())) }
        if showZone { parts.append(Format.zoneAbbreviation(zone, at: slot)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// What a jump next to this cell does to the wall clock, in words.
    private func jumpExplanation(before: Timeline.Jump?, after: Timeline.Jump?, zone: TimeZone) -> String? {
        guard let jump = before ?? after else { return nil }
        let from = Format.time(minuteOfDay: jump.wallMinuteBefore, use24Hour: use24Hour)
        let to = Format.time(minuteOfDay: jump.wallMinuteAfter, use24Hour: use24Hour)
        if jump.isForward {
            let lastSkipped = Format.time(minuteOfDay: (jump.wallMinuteAfter + 1439) % 1440, use24Hour: use24Hour)
            return "Clocks jump from \(from) to \(to), so \(from)–\(lastSkipped) doesn't exist here."
        }
        let lastRepeated = Format.time(minuteOfDay: (jump.wallMinuteBefore + 1439) % 1440, use24Hour: use24Hour)
        let which = before != nil ? "second" : "first"
        let abbreviation = Format.zoneAbbreviation(zone, at: slot)
        return "Clocks go back from \(from) to \(to), so \(to)–\(lastRepeated) happens twice. This is the \(which) time (\(abbreviation))."
    }

    private func tooltip(zone: TimeZone, clocksChangeInside: Bool, daylight: Daylight?, explanation: String?) -> String {
        var text = "\(place.name): \(Format.shortDay(slot, in: zone)), \(Format.time(slot, in: zone, use24Hour: use24Hour)) (\(Format.utcOffset(zone.secondsFromGMT(for: slot))))"
        if let daylight { text += " — \(daylight.title)" }
        if let explanation { text += "\n" + explanation }
        if clocksChangeInside { text += "\nClocks change during this hour." }
        return text
    }
}

private struct VerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

extension Daylight {
    var fill: Color {
        switch self {
        case .day: .yellow
        case .twilight: .orange.opacity(0.55)
        case .night: .indigo.opacity(0.6)
        }
    }

    var title: String {
        switch self {
        case .day: "daylight"
        case .twilight: "twilight"
        case .night: "dark"
        }
    }
}

private struct OverlapCell: View {
    let places: [Place]
    let slot: Date

    var body: some View {
        let states = places.map { $0.availability(at: slot) }
        let working = states.filter { $0 == .working }.count
        let everyoneWorking = working == states.count
        let nobodyAsleep = !states.contains(.night)

        RoundedRectangle(cornerRadius: 5)
            .fill(everyoneWorking ? Color.green.opacity(0.75) : nobodyAsleep ? Color.yellow.opacity(0.45) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.12)))
            .overlay {
                if everyoneWorking {
                    Image(systemName: "checkmark").font(.callout.weight(.bold))
                } else {
                    Text("\(working)/\(states.count)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(nobodyAsleep ? .primary : .secondary)
                }
            }
            .help(everyoneWorking ? "Everyone is in working hours" : "\(working) of \(states.count) in working hours" + (nobodyAsleep ? "; nobody is outside the shoulder hours" : ""))
    }
}
