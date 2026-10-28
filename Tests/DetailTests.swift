import Foundation
import Testing
@testable import Meridian

struct DetailTests {
    let denver = TimeZone(identifier: "America/Denver")!
    let utc = TimeZone(identifier: "UTC")!

    /// 08:00 UTC on 1 Nov 2026: Denver's 2:00 am MDT becomes 1:00 am MST.
    @Test func fallBackRepeatsAnHour() throws {
        let slots = Timeline.slots(on: CivilDay(year: 2026, month: 11, day: 1), in: denver)
        let jumps = slots.compactMap { Timeline.jump(in: denver, at: $0) }
        let jump = try #require(jumps.first)
        #expect(jumps.count == 1)
        #expect(!jump.isForward)
        #expect(jump.wallMinuteBefore == 120)
        #expect(jump.wallMinuteAfter == 60)
        // The cells either side of the jump both read 1 am.
        let index = try #require(slots.firstIndex(of: jump.moment))
        #expect(Calendar.gregorian(in: denver).component(.hour, from: slots[index - 1]) == 1)
        #expect(Calendar.gregorian(in: denver).component(.hour, from: slots[index]) == 1)
    }

    @Test func springForwardSkipsAnHour() throws {
        let slots = Timeline.slots(on: CivilDay(year: 2026, month: 3, day: 8), in: denver)
        let jump = try #require(slots.compactMap { Timeline.jump(in: denver, at: $0) }.first)
        #expect(jump.isForward)
        #expect(jump.wallMinuteBefore == 120)
        #expect(jump.wallMinuteAfter == 180)
    }

    @Test func abbreviationsNeverFallBackToGMTOffsets() {
        let london = TimeZone(identifier: "Europe/London")!
        let summer = CivilDay(year: 2026, month: 7, day: 1).noon(in: utc)
        let abbreviation = Format.zoneAbbreviation(london, at: summer)
        #expect(!abbreviation.hasPrefix("GMT+"))
        #expect(Format.zoneAbbreviation(TimeZone(secondsFromGMT: 3600)!, at: summer) == "UTC+1")
    }

    /// Stockholm at the winter solstice: the sun barely clears 7°.
    @Test func solarElevationMatchesKnownValues() {
        let noon = Date(timeIntervalSince1970: 1_797_850_080)  // 21 Dec 2026, 10:48 UTC
        let midnight = noon.addingTimeInterval(-11 * 3600)
        let elevation = Solar.elevation(at: noon, latitude: 59.33, longitude: 18.07)
        #expect(abs(elevation - 7.2) < 1)
        #expect(Daylight(sunElevation: Solar.elevation(at: midnight, latitude: 59.33, longitude: 18.07)) == .night)
        // Denver at 1 pm on the June solstice: high sun.
        let denverNoon = Date(timeIntervalSince1970: 1_781_982_000)  // 20 Jun 2026, 19:00 UTC
        #expect(Solar.elevation(at: denverNoon, latitude: 39.74, longitude: -104.99) > 70)
    }

    @Test func placesSavedBeforeCoordinatesStillDecode() throws {
        let json = #"[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Slough","detail":"England","timeZoneID":"Europe/London","note":"","workStart":540,"workEnd":1020}]"#
        let places = try JSONDecoder().decode([Place].self, from: Data(json.utf8))
        #expect(places.first?.latitude == nil)
        #expect(places.first?.daylight(at: .now) == nil)
    }
}
