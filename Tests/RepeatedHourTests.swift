import Foundation
import Testing
@testable import Meridian

/// The repeated hour when the clocks go back must be told apart in every
/// row, including rows whose change falls mid-column because they're a
/// non-whole number of hours from the reference zone.
struct RepeatedHourTests {
    let kolkata = TimeZone(identifier: "Asia/Kolkata")!
    let denver = TimeZone(identifier: "America/Denver")!
    let newYork = TimeZone(identifier: "America/New_York")!
    let stJohns = TimeZone(identifier: "America/St_Johns")!
    let fallBack = CivilDay(year: 2026, month: 11, day: 1)

    /// The slot that starts at `hour`:`minute` UTC on `day`.
    private func utc(_ hour: Int, _ minute: Int = 0, on day: CivilDay = CivilDay(year: 2026, month: 11, day: 1)) -> Date {
        let utc = TimeZone(identifier: "UTC")!
        return Calendar.gregorian(in: utc).date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
    }

    /// Denver falls back at 08:00 UTC = 13:30 IST, inside the 13:00 IST
    /// column. Both that column and the next read 1:30 am in Denver.
    @Test func kolkataReferenceDenverRow() throws {
        let slots = Timeline.slots(on: fallBack, in: kolkata)
        let first = try #require(slots.first { $0 == utc(7, 30) })
        let second = first.addingTimeInterval(3600)
        #expect(slots.contains(second))

        #expect(Format.time(first, in: denver, use24Hour: false) == "1:30 am")
        #expect(Format.time(second, in: denver, use24Hour: false) == "1:30 am")

        #expect(Timeline.wallTimeRepeats(in: denver, at: first))
        #expect(Timeline.wallTimeRepeats(in: denver, at: second))
        #expect(Timeline.cellNeedsZone(in: denver, slot: first))
        #expect(Timeline.cellNeedsZone(in: denver, slot: second))
        // Neither column has a jump on its edge; only the first has the change inside it.
        #expect(Timeline.jump(in: denver, at: first) == nil && Timeline.jump(in: denver, at: second) == nil)
        #expect(Timeline.clocksChange(in: denver, duringHourStarting: first))
        #expect(!Timeline.clocksChange(in: denver, duringHourStarting: second))

        #expect(Format.zoneAbbreviation(denver, at: first) != Format.zoneAbbreviation(denver, at: second))

        // 12:30 am and 2:30 am MST happen once.
        let before = first.addingTimeInterval(-3600)
        let after = second.addingTimeInterval(3600)
        #expect(!Timeline.wallTimeRepeats(in: denver, at: before))
        #expect(!Timeline.wallTimeRepeats(in: denver, at: after))
        #expect(!Timeline.cellNeedsZone(in: denver, slot: before))
        #expect(!Timeline.cellNeedsZone(in: denver, slot: after))

        // The reference zone itself never changes.
        #expect(slots.allSatisfy { !Timeline.cellNeedsZone(in: kolkata, slot: $0) })
    }

    /// St. John's falls back at 02:00 NDT = 04:30 UTC, inside New York's
    /// 00:00 EDT column; the 01:00 EDT column is the second 1:30 am.
    @Test func newYorkReferenceStJohnsRow() {
        let slots = Timeline.slots(on: fallBack, in: newYork)
        let first = utc(4)
        let second = utc(5)
        #expect(slots.contains(first) && slots.contains(second))

        #expect(Format.time(first, in: stJohns, use24Hour: true) == "01:30")
        #expect(Format.time(second, in: stJohns, use24Hour: true) == "01:30")
        #expect(Timeline.wallTimeRepeats(in: stJohns, at: first))
        #expect(Timeline.wallTimeRepeats(in: stJohns, at: second))
        #expect(Timeline.cellNeedsZone(in: stJohns, slot: first))
        #expect(Timeline.cellNeedsZone(in: stJohns, slot: second))
        #expect(stJohns.secondsFromGMT(for: first) != stJohns.secondsFromGMT(for: second))

        #expect(!Timeline.cellNeedsZone(in: stJohns, slot: utc(3)))
        #expect(!Timeline.cellNeedsZone(in: stJohns, slot: utc(6)))
    }

    /// Whole hours apart, the repeated hour sits either side of a jump on a
    /// column edge, as before, and no other cells gain a zone.
    @Test func newYorkReferenceDenverRowUnchanged() {
        let slots = Timeline.slots(on: fallBack, in: newYork)
        let flagged = slots.filter { Timeline.cellNeedsZone(in: denver, slot: $0) }
        #expect(flagged == [utc(7), utc(8)])
        let edgeJumps = slots.filter {
            Timeline.jump(in: denver, at: $0) != nil || Timeline.jump(in: denver, at: $0.addingTimeInterval(3600)) != nil
        }
        #expect(flagged == edgeJumps)
        #expect(slots.allSatisfy { !Timeline.clocksChange(in: denver, duringHourStarting: $0) })
    }

    @Test func springForwardAndPlainDaysDontRepeat() {
        let springForward = CivilDay(year: 2026, month: 3, day: 8)
        for slot in Timeline.slots(on: springForward, in: kolkata) {
            #expect(!Timeline.wallTimeRepeats(in: denver, at: slot))
        }
        for slot in Timeline.slots(on: CivilDay(year: 2026, month: 10, day: 28), in: kolkata) {
            #expect(!Timeline.cellNeedsZone(in: denver, slot: slot))
            #expect(!Timeline.wallTimeRepeats(in: kolkata, at: slot))
        }
    }
}
