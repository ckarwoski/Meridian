import AppKit
import SwiftUI

struct PlannerView: View {
    static let windowID = "planner"

    var inMenuBar = false

    @Environment(PlannerStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.use24Hour) private var use24Hour = Format.localePrefers24Hour
    @AppStorage(SettingsKey.lookaheadDays) private var lookaheadDays = 14
    @State private var isAdding = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let slots = store.slots
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        PlannerGrid(slots: slots, now: now, use24Hour: use24Hour)
                        Legend()
                        ClockChangeList(changes: clockChanges(now: now), slots: slots, use24Hour: use24Hour)
                    }
                    .padding(16)
                }
                if let slot = store.selectedSlot {
                    Divider()
                    SelectionSummary(slot: slot, use24Hour: use24Hour)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
        }
        .background(.background)
    }

    /// Changes from today (or the shown day, if earlier) to the end of the
    /// look-ahead window after the shown day. Changes between today and a
    /// future shown day matter too: they make that day's gaps differ from
    /// today's.
    private func clockChanges(now: Date) -> [ClockChange] {
        let zone = store.referenceZone
        let shownStart = store.day.start(in: zone)
        let todayStart = CivilDay(now, in: zone).start(in: zone)
        let end = store.day.adding(days: max(lookaheadDays, 1)).start(in: zone)
        return ClockChanges.find(places: store.orderedPlaces, referenceZone: zone, from: min(shownStart, todayStart), to: end)
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Button { store.shift(days: -1) } label: { Image(systemName: "chevron.left") }
                    .help("Previous day (⌘←)")
                Button("Today") { store.showToday() }
                    .disabled(store.isShowingToday)
                    .help("Today (⌘T)")
                Button { store.shift(days: 1) } label: { Image(systemName: "chevron.right") }
                    .help("Next day (⌘→)")
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 1) {
                Text(Format.longDay(store.day.noon(in: store.referenceZone), in: store.referenceZone))
                    .font(.title3.weight(.semibold))
                Text("Hours shown in \(store.reference.name) time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DatePicker("Date", selection: dayBinding, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()

            Spacer()

            Picker("Flag clock changes within", selection: $lookaheadDays) {
                Text("1 week").tag(7)
                Text("2 weeks").tag(14)
                Text("1 month").tag(31)
                Text("3 months").tag(92)
            }
            .fixedSize()
            .help("How far past the shown day to look for daylight-saving changes")

            Button { isAdding = true } label: { Label("Add Place", systemImage: "plus") }
                .keyboardShortcut("n", modifiers: .command)
                .help("Add a city or time zone (⌘N)")
                .popover(isPresented: $isAdding, arrowEdge: .bottom) {
                    AddPlaceView(isPresented: $isAdding)
                        .environment(store)
                }

            if inMenuBar {
                Button {
                    openWindow(id: Self.windowID)
                    NSApp.activate()
                } label: { Image(systemName: "macwindow") }
                    .help("Open in a window")
                SettingsLink { Image(systemName: "gearshape") }
                    .help("Settings")
            }
        }
    }

    /// The date picker works in the Mac's own calendar; the planner's day is
    /// a civil date, so convert through noon to avoid landing on a neighbour.
    private var dayBinding: Binding<Date> {
        Binding(
            get: { store.day.noon(in: .current) },
            set: { store.show(CivilDay($0, in: .current)) }
        )
    }
}

private struct Legend: View {
    @AppStorage(SettingsKey.showDaylight) private var showDaylight = true

    var body: some View {
        HStack(spacing: 16) {
            item(.working, "Working hours")
            item(.shoulder, "Within 2h of working hours")
            item(.night, "Outside")
            HStack(spacing: 4) {
                Rectangle().fill(.orange).frame(width: 2.5, height: 12)
                Text("Clocks change (dashed: an hour is skipped)")
            }
            if showDaylight {
                HStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Daylight.night.fill
                        Daylight.twilight.fill
                        Daylight.day.fill
                    }
                    .frame(width: 18, height: 3)
                    Text("Dark · twilight · daylight")
                }
            }
            Spacer()
            Text("Click a place to edit its working hours · click an hour to compare it")
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func item(_ availability: Availability, _ title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(availability.fill)
                .frame(width: 14, height: 10)
            Text(title)
        }
    }
}
