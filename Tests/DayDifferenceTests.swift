import Foundation
import Testing
@testable import Meridian

struct DayDifferenceTests {
    let pagoPago = TimeZone(identifier: "Pacific/Pago_Pago")!
    let kiritimati = TimeZone(identifier: "Pacific/Kiritimati")!

    /// 28 Oct 2026 at 10:00 UTC: Oct 27 23:00 in Pago Pago, Oct 29 00:00 in
    /// Kiritimati.
    var slot: Date {
        Calendar.gregorian(in: .gmt).date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 10))!
    }

    @Test func daysBetweenCivilDays() {
        let day = CivilDay(year: 2026, month: 10, day: 28)
        #expect(day.days(to: day) == 0)
        #expect(day.days(to: CivilDay(year: 2026, month: 10, day: 29)) == 1)
        #expect(day.days(to: CivilDay(year: 2026, month: 10, day: 26)) == -2)
        // Across a month, a year and a leap day.
        #expect(CivilDay(year: 2026, month: 12, day: 31).days(to: CivilDay(year: 2027, month: 1, day: 2)) == 2)
        #expect(CivilDay(year: 2028, month: 2, day: 28).days(to: CivilDay(year: 2028, month: 3, day: 1)) == 2)
    }

    @Test func pagoPagoToKiritimatiIsTwoDays() {
        let reference = CivilDay(slot, in: pagoPago)
        let there = CivilDay(slot, in: kiritimati)
        #expect(reference == CivilDay(year: 2026, month: 10, day: 27))
        #expect(there == CivilDay(year: 2026, month: 10, day: 29))
        #expect(reference.days(to: there) == 2)
        #expect(there.days(to: reference) == -2)
    }

    /// 28 Oct 2026 at 03:00 UTC: Oct 28 03:00 in London, Oct 27 23:00 in
    /// New York.
    @Test func londonToNewYorkIsPreviousDay() {
        let slot = Calendar.gregorian(in: .gmt).date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 3))!
        let london = CivilDay(slot, in: TimeZone(identifier: "Europe/London")!)
        let newYork = CivilDay(slot, in: TimeZone(identifier: "America/New_York")!)
        #expect(london.days(to: newYork) == -1)
        #expect(newYork.days(to: london) == 1)
    }

    @Test func wording() {
        #expect(SelectionSummary.dayNote(0) == "")
        #expect(SelectionSummary.dayNote(1) == " · next day")
        #expect(SelectionSummary.dayNote(-1) == " · previous day")
        #expect(SelectionSummary.dayNote(2) == " · 2 days later")
        #expect(SelectionSummary.dayNote(-2) == " · 2 days earlier")
    }
}
