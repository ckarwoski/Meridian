import Foundation
import Testing
@testable import Meridian

struct AvailabilityTests {
    let utc = TimeZone(identifier: "UTC")!

    func place(_ start: Int, _ end: Int) -> Place {
        Place(name: "Reykjavik", detail: "", timeZoneID: "UTC", workStart: start * 60, workEnd: end * 60)
    }

    /// 1 Jul 2026 at `hour`:`minute` UTC.
    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.gregorian(in: utc).date(from: DateComponents(year: 2026, month: 7, day: 1, hour: hour, minute: minute))!
    }

    @Test func nineToFive() {
        let place = place(9, 17)
        #expect(place.availability(at: at(9)) == .working)
        #expect(place.availability(at: at(16, 59)) == .working)
        #expect(place.availability(at: at(7)) == .shoulder)
        #expect(place.availability(at: at(6, 59)) == .night)
        #expect(place.availability(at: at(17)) == .shoulder)
        #expect(place.availability(at: at(18, 59)) == .shoulder)
        #expect(place.availability(at: at(19)) == .night)
        #expect(place.availability(at: at(0)) == .night)
    }

    @Test func overnightShift() {
        let place = place(22, 6)
        #expect(place.availability(at: at(23)) == .working)
        #expect(place.availability(at: at(5, 59)) == .working)
        #expect(place.availability(at: at(6)) == .shoulder)
        #expect(place.availability(at: at(7, 59)) == .shoulder)
        #expect(place.availability(at: at(8)) == .night)
        #expect(place.availability(at: at(19, 59)) == .night)
        #expect(place.availability(at: at(20)) == .shoulder)
    }

    /// A three-hour gap: the two shoulders overlap and wrap past midnight.
    @Test func shortGapWrappingMidnight() {
        let place = place(1, 22)
        #expect(place.availability(at: at(22)) == .shoulder)
        #expect(place.availability(at: at(23)) == .shoulder)
        #expect(place.availability(at: at(0)) == .shoulder)
        #expect(place.availability(at: at(0, 59)) == .shoulder)
        #expect(place.availability(at: at(1)) == .working)
    }

    /// A four-hour gap: the shoulders meet exactly.
    @Test func fourHourGap() {
        let place = place(8, 4)
        #expect(place.availability(at: at(4)) == .shoulder)
        #expect(place.availability(at: at(5, 59)) == .shoulder)
        #expect(place.availability(at: at(6)) == .shoulder)
        #expect(place.availability(at: at(7, 59)) == .shoulder)
        #expect(place.availability(at: at(8)) == .working)
        #expect(place.availability(at: at(3, 59)) == .working)
    }

    /// No working hours at all: never working, never shoulder.
    @Test func zeroLengthWindowIsAllOff() {
        let place = place(9, 9)
        for hour in 0..<24 {
            #expect(place.availability(at: at(hour)) == .night)
        }
    }
}
