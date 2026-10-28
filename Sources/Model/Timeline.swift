import Foundation

/// A calendar date with no time zone attached. The planner's day is a civil
/// day in the reference zone, so it must not drift when the Mac's own zone
/// differs from the reference.
struct CivilDay: Hashable, Codable, Comparable, Sendable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, in timeZone: TimeZone) {
        let parts = Calendar.gregorian(in: timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Noon on this day in `timeZone`: always exists, unlike midnight in a
    /// few zones that change clocks at 00:00.
    func noon(in timeZone: TimeZone) -> Date {
        let parts = DateComponents(year: year, month: month, day: day, hour: 12)
        return Calendar.gregorian(in: timeZone).date(from: parts) ?? .now
    }

    func start(in timeZone: TimeZone) -> Date {
        Calendar.gregorian(in: timeZone).startOfDay(for: noon(in: timeZone))
    }

    func adding(days: Int) -> CivilDay {
        let utc = TimeZone(identifier: "UTC")!
        let moved = Calendar.gregorian(in: utc).date(byAdding: .day, value: days, to: noon(in: utc)) ?? .now
        return CivilDay(moved, in: utc)
    }

    static func < (lhs: CivilDay, rhs: CivilDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

enum Timeline {
    /// The start of each hour column for `day` in `timeZone`. Steps are real
    /// hours, so a day when the clocks change has 23 or 25 columns.
    static func slots(on day: CivilDay, in timeZone: TimeZone) -> [Date] {
        let start = day.start(in: timeZone)
        let end = day.adding(days: 1).start(in: timeZone)
        return Array(stride(from: start, to: end, by: 3600))
    }

    /// Whether the zone's UTC offset changes strictly inside the hour
    /// starting at `slot`. Changes exactly on an hour boundary are a `Jump`.
    static func clocksChange(in timeZone: TimeZone, duringHourStarting slot: Date) -> Bool {
        timeZone.secondsFromGMT(for: slot) != timeZone.secondsFromGMT(for: slot.addingTimeInterval(3599))
    }

    /// A change of UTC offset at an exact instant, as it reads on the wall.
    struct Jump: Hashable, Sendable {
        let moment: Date
        let offsetBefore: Int
        let offsetAfter: Int

        var isForward: Bool { offsetAfter > offsetBefore }
        /// Local minute of day just as the change happens, on the old clock:
        /// 120 for the US's 2:00 am, either way.
        var wallMinuteBefore: Int { Self.minuteOfDay(moment, offset: offsetBefore) }
        /// The same instant on the new clock: 180 after springing forward
        /// from 2:00 am, 60 after falling back.
        var wallMinuteAfter: Int { Self.minuteOfDay(moment, offset: offsetAfter) }

        private static func minuteOfDay(_ date: Date, offset: Int) -> Int {
            let zone = TimeZone(secondsFromGMT: offset) ?? .gmt
            let parts = Calendar.gregorian(in: zone).dateComponents([.hour, .minute], from: date)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }

    /// The jump in `timeZone` exactly at `moment`, if there is one.
    static func jump(in timeZone: TimeZone, at moment: Date) -> Jump? {
        let before = timeZone.secondsFromGMT(for: moment.addingTimeInterval(-1))
        let after = timeZone.secondsFromGMT(for: moment)
        return before == after ? nil : Jump(moment: moment, offsetBefore: before, offsetAfter: after)
    }

    /// Whether the wall time at `moment` happens twice in `timeZone`, as
    /// 1:30 am does on the day the US falls back. Looks for the same wall
    /// reading on any other offset the zone uses within a day either side.
    static func wallTimeRepeats(in timeZone: TimeZone, at moment: Date) -> Bool {
        let offset = timeZone.secondsFromGMT(for: moment)
        let nearby = Set([-86400.0, 86400.0].map { timeZone.secondsFromGMT(for: moment.addingTimeInterval($0)) })
        return nearby.contains { other in
            // The instant that reads the same on the wall under `other`.
            other != offset && timeZone.secondsFromGMT(for: moment.addingTimeInterval(TimeInterval(offset - other))) == other
        }
    }

    /// Whether the hour cell starting at `slot` should name its zone's
    /// abbreviation, so the two copies of a repeated hour can be told
    /// apart: "1:30a MDT", "1:30a MST". True next to a jump on either edge,
    /// when the offset changes inside the hour, or when the cell's wall
    /// time happens twice.
    static func cellNeedsZone(in timeZone: TimeZone, slot: Date) -> Bool {
        jump(in: timeZone, at: slot) != nil
            || jump(in: timeZone, at: slot.addingTimeInterval(3600)) != nil
            || clocksChange(in: timeZone, duringHourStarting: slot)
            || wallTimeRepeats(in: timeZone, at: slot)
    }
}

/// A daylight-saving transition in one zone.
struct ClockChange: Identifiable, Hashable, Sendable {
    let date: Date
    let timeZoneID: String
    /// Every place in this zone, e.g. "Slough, London".
    let placeNames: [String]
    let isReference: Bool
    let offsetBefore: Int
    let offsetAfter: Int

    var id: String { "\(timeZoneID)@\(date.timeIntervalSince1970)" }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    /// Positive when the clocks go forward.
    var delta: Int { offsetAfter - offsetBefore }
}

enum ClockChanges {
    /// Every transition in `[start, end)` across the places' zones. Places
    /// that share a zone are reported together.
    static func find(places: [Place], referenceZone: TimeZone, from start: Date, to end: Date) -> [ClockChange] {
        var groups: [(zone: TimeZone, names: [String])] = []
        for place in places {
            if let index = groups.firstIndex(where: { $0.zone.identifier == place.timeZoneID }) {
                groups[index].names.append(place.name)
            } else {
                groups.append((place.timeZone, [place.name]))
            }
        }

        var changes: [ClockChange] = []
        for group in groups {
            let zone = group.zone
            let isReference = zone.identifier == referenceZone.identifier
            var cursor = start.addingTimeInterval(-1)
            while let moment = zone.nextDaylightSavingTimeTransition(after: cursor), moment < end {
                cursor = moment
                let before = zone.secondsFromGMT(for: moment.addingTimeInterval(-1))
                let after = zone.secondsFromGMT(for: moment)
                guard before != after else { continue }

                changes.append(ClockChange(
                    date: moment,
                    timeZoneID: zone.identifier,
                    placeNames: group.names,
                    isReference: isReference,
                    offsetBefore: before,
                    offsetAfter: after
                ))
            }
        }
        return changes.sorted { $0.date < $1.date }
    }
}

extension ClockChange {
    /// The local date of the change.
    var localDay: CivilDay { CivilDay(date, in: timeZone) }

    /// The local clock reading when the change happens, on the old offset:
    /// 120 for the US's 2 am, whichever way the clocks go.
    var localMinuteBefore: Int {
        let oldZone = TimeZone(secondsFromGMT: offsetBefore) ?? timeZone
        let parts = Calendar.gregorian(in: oldZone).dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}

/// Changes that move clocks by the same amount on the same local date, such
/// as every US zone on one Sunday or every EU zone at 01:00 UTC.
struct ClockChangeGroup: Identifiable, Hashable, Sendable {
    /// In time order; never empty.
    let changes: [ClockChange]

    var id: String { changes.map(\.id).joined(separator: "|") }
    var first: ClockChange { changes[0] }
    var delta: Int { first.delta }
    var placeNames: [String] { changes.flatMap(\.placeNames) }

    /// The shared local clock time, if every zone changes at the same one.
    var localMinuteBefore: Int? {
        let minutes = Set(changes.map(\.localMinuteBefore))
        return minutes.count == 1 ? minutes.first : nil
    }

    /// Groups changes by local date and size, keeping time order.
    static func grouping(_ changes: [ClockChange]) -> [ClockChangeGroup] {
        var groups: [[ClockChange]] = []
        for change in changes.sorted(by: { $0.date < $1.date }) {
            if let index = groups.firstIndex(where: { $0[0].localDay == change.localDay && $0[0].delta == change.delta }) {
                groups[index].append(change)
            } else {
                groups.append([change])
            }
        }
        return groups.map(ClockChangeGroup.init)
    }
}

extension ClockChanges {
    /// The range the planner searches: from the start of today or the shown
    /// day, whichever is earlier, through the whole of the day `days` after
    /// the shown day.
    static func lookahead(shown: CivilDay, today: CivilDay, days: Int, in zone: TimeZone) -> Range<Date> {
        let last = shown.adding(days: max(days, 1))
        return min(shown, today).start(in: zone)..<last.adding(days: 1).start(in: zone)
    }
}

extension CivilDay {
    /// Whole calendar days from this day to `other`: 2 from Oct 27 to
    /// Oct 29, negative when `other` is earlier.
    func days(to other: CivilDay) -> Int {
        let utc = TimeZone(identifier: "UTC")!
        return Calendar.gregorian(in: utc).dateComponents([.day], from: noon(in: utc), to: other.noon(in: utc)).day ?? 0
    }
}
