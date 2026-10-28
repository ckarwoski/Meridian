import Foundation
import Testing
@testable import Meridian

struct LookaheadTests {
    let chicago = TimeZone(identifier: "America/Chicago")!
    let place = Place(name: "Chicago", detail: "", timeZoneID: "America/Chicago")

    private func changes(in range: Range<Date>) -> [ClockChange] {
        ClockChanges.find(places: [place], referenceZone: chicago, from: range.lowerBound, to: range.upperBound)
    }

    /// Chicago falls back on 1 Nov 2026, exactly 14 days after 18 Oct.
    @Test func includesTheLastDay() {
        let shown = CivilDay(year: 2026, month: 10, day: 18)
        let range = ClockChanges.lookahead(shown: shown, today: shown, days: 14, in: chicago)
        #expect(changes(in: range).map(\.localDay) == [CivilDay(year: 2026, month: 11, day: 1)])
    }

    @Test func stopsAfterTheLastDay() {
        let shown = CivilDay(year: 2026, month: 10, day: 17)
        let range = ClockChanges.lookahead(shown: shown, today: shown, days: 14, in: chicago)
        #expect(changes(in: range).isEmpty)
        #expect(range.upperBound == CivilDay(year: 2026, month: 11, day: 1).start(in: chicago))
    }

    @Test func startsAtTheEarlierOfTodayAndTheShownDay() {
        let today = CivilDay(year: 2026, month: 10, day: 28)
        let past = CivilDay(year: 2026, month: 10, day: 20)
        let future = CivilDay(year: 2026, month: 12, day: 1)
        #expect(ClockChanges.lookahead(shown: past, today: today, days: 7, in: chicago).lowerBound == past.start(in: chicago))
        #expect(ClockChanges.lookahead(shown: future, today: today, days: 7, in: chicago).lowerBound == today.start(in: chicago))
        // A future shown day still flags the change between today and it.
        #expect(!changes(in: ClockChanges.lookahead(shown: future, today: today, days: 7, in: chicago)).isEmpty)
    }
}
