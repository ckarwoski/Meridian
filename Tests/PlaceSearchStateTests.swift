import MapKit
import Testing
@testable import Meridian

@MainActor
struct PlaceSearchStateTests {
    let results = [MKLocalSearchCompletion(), MKLocalSearchCompletion()]

    @Test func completionsClearWhenQueryChanges() {
        let search = PlaceSearch()
        search.update(query: "London")
        search.accept(results)
        #expect(search.completions.count == 2)

        // Until MapKit answers for "UTC", London mustn't be what Return adds.
        search.update(query: "UTC")
        #expect(search.completions.isEmpty)
        #expect(search.zoneMatches.first?.timeZoneID == "UTC")
    }

    @Test func sameQueryKeepsCompletions() {
        let search = PlaceSearch()
        search.update(query: "London")
        search.accept(results)
        search.update(query: "London ")
        #expect(search.completions.count == 2)
    }

    @Test func emptyQueryIgnoresLateResults() {
        let search = PlaceSearch()
        search.update(query: "London")
        search.update(query: "")
        search.accept(results)
        #expect(search.completions.isEmpty)
    }

    @Test func emptyQueryIgnoresLateFailure() {
        let search = PlaceSearch()
        search.update(query: "London")
        search.update(query: "")
        search.fail()
        #expect(!search.failed)
    }
}
