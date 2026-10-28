import Foundation
import Testing
@testable import Meridian

struct TimelineTests {
    let chicago = Place(name: "Chicago", detail: "", timeZoneID: "America/Chicago")
    let slough = Place(name: "Slough", detail: "England, United Kingdom", timeZoneID: "Europe/London")
    let london = Place(name: "London", detail: "", timeZoneID: "Europe/London")
    let kolkata = Place(name: "Pune", detail: "", timeZoneID: "Asia/Kolkata")

    @Test func ordinaryDayHas24Columns() {
        #expect(Timeline.slots(on: CivilDay(year: 2026, month: 10, day: 28), in: chicago.timeZone).count == 24)
    }

    @Test func fallBackDayHas25Columns() {
        #expect(Timeline.slots(on: CivilDay(year: 2026, month: 11, day: 1), in: chicago.timeZone).count == 25)
    }

    @Test func springForwardDayHas23Columns() {
        #expect(Timeline.slots(on: CivilDay(year: 2026, month: 3, day: 8), in: chicago.timeZone).count == 23)
    }

    @Test func civilDayAddsAcrossMonths() {
        #expect(CivilDay(year: 2026, month: 10, day: 31).adding(days: 1) == CivilDay(year: 2026, month: 11, day: 1))
        #expect(CivilDay(year: 2026, month: 1, day: 1).adding(days: -1) == CivilDay(year: 2025, month: 12, day: 31))
    }

    /// Late October: Europe falls back a week before the US.
    @Test func transatlanticGapShiftsTwice() {
        let utc = TimeZone(identifier: "UTC")!
        let changes = ClockChanges.find(
            places: [chicago, slough, london],
            referenceZone: chicago.timeZone,
            from: CivilDay(year: 2026, month: 10, day: 20).start(in: utc),
            to: CivilDay(year: 2026, month: 11, day: 10).start(in: utc)
        )
        #expect(changes.count == 2)

        let uk = changes[0]
        #expect(uk.timeZoneID == "Europe/London")
        #expect(uk.placeNames == ["Slough", "London"])
        #expect(!uk.isReference)
        #expect(uk.delta == -3600)

        let us = changes[1]
        #expect(us.timeZoneID == "America/Chicago")
        #expect(us.isReference)
        #expect(us.delta == -3600)
    }

    @Test func zoneWithoutDaylightSavingReportsNothing() {
        let utc = TimeZone(identifier: "UTC")!
        let changes = ClockChanges.find(
            places: [kolkata],
            referenceZone: kolkata.timeZone,
            from: CivilDay(year: 2026, month: 1, day: 1).start(in: utc),
            to: CivilDay(year: 2027, month: 1, day: 1).start(in: utc)
        )
        #expect(changes.isEmpty)
    }

    func groups(_ places: [Place], from: CivilDay, to: CivilDay) -> [ClockChangeGroup] {
        let utc = TimeZone(identifier: "UTC")!
        let changes = ClockChanges.find(places: places, referenceZone: places[0].timeZone, from: from.start(in: utc), to: to.start(in: utc))
        return ClockChangeGroup.grouping(changes)
    }

    /// US zones change on the same date at the same local time (2 am), an
    /// hour apart in real time.
    @Test func usZonesMergeWithTheirSharedLocalTime() {
        let newYork = Place(name: "New York", detail: "", timeZoneID: "America/New_York")
        let denver = Place(name: "Denver", detail: "", timeZoneID: "America/Denver")
        let result = groups([denver, newYork], from: CivilDay(year: 2026, month: 10, day: 28), to: CivilDay(year: 2026, month: 11, day: 5))
        #expect(result.count == 1)
        #expect(result[0].placeNames == ["New York", "Denver"])
        #expect(result[0].localMinuteBefore == 120)
    }

    /// EU zones change at the same instant, so local times differ.
    @Test func euZonesMergeWithoutASharedLocalTime() {
        let stockholm = Place(name: "Stockholm", detail: "", timeZoneID: "Europe/Stockholm")
        let vilnius = Place(name: "Vilnius", detail: "", timeZoneID: "Europe/Vilnius")
        let result = groups([stockholm, vilnius], from: CivilDay(year: 2026, month: 10, day: 20), to: CivilDay(year: 2026, month: 10, day: 28))
        #expect(result.count == 1)
        #expect(result[0].changes.map(\.localMinuteBefore) == [180, 240])
        #expect(result[0].localMinuteBefore == nil)
    }

    /// Lord Howe Island moves 30 minutes on the same day Sydney moves an hour.
    @Test func differentJumpsStaySeparate() {
        let sydney = Place(name: "Sydney", detail: "", timeZoneID: "Australia/Sydney")
        let lordHowe = Place(name: "Lord Howe", detail: "", timeZoneID: "Australia/Lord_Howe")
        let result = groups([sydney, lordHowe], from: CivilDay(year: 2026, month: 9, day: 28), to: CivilDay(year: 2026, month: 10, day: 10))
        #expect(result.count == 2)
        #expect(Set(result.map(\.delta)) == [1800, 3600])
    }

    @Test func availabilityFollowsLocalHours() {
        // 15:00 UTC on 28 Oct 2026 is 10:00 in Chicago and 15:00 in Slough.
        let moment = Date(timeIntervalSince1970: 1_793_199_600)
        #expect(chicago.availability(at: moment) == .working)
        #expect(slough.availability(at: moment) == .working)
        // 20:30 in Pune: within two hours of a 17:00 finish? No — 3.5h.
        #expect(kolkata.availability(at: moment) == .night)
    }

    @Test func overnightWorkWindowWraps() {
        #expect(Place.contains(23 * 60, from: 22 * 60, to: 6 * 60))
        #expect(Place.contains(2 * 60, from: 22 * 60, to: 6 * 60))
        #expect(!Place.contains(12 * 60, from: 22 * 60, to: 6 * 60))
    }

    @Test func formatsGaps() {
        #expect(Format.offset(5 * 3600) == "+5h")
        #expect(Format.offset(-(3 * 3600 + 1800)) == "−3h30")
        #expect(Format.utcOffset(19800) == "UTC+5:30")
    }
}
