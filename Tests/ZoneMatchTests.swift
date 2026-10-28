import Foundation
import Testing
@testable import Meridian

@MainActor
struct ZoneMatchTests {
    func ids(_ query: String) -> [String] {
        PlaceSearch.zones(matching: query).map(\.timeZoneID)
    }

    @Test(arguments: ["time", "Time", "in", "co", "al", "ver", "zone"])
    func unrelatedQueriesDontPinUTC(_ query: String) {
        #expect(ids(query).first != "UTC")
    }

    @Test(arguments: ["utc", "UTC", "UT", "ut", "universal", "Universal Time", "coordinated"])
    func utcQueriesOfferUTCFirst(_ query: String) {
        #expect(ids(query).first == "UTC")
    }

    @Test(arguments: ["utc", "UT", "universal", "coordinated universal time"])
    func utcAppearsOnce(_ query: String) {
        #expect(ids(query).count(where: { $0 == "UTC" }) == 1)
    }

    @Test func cityQueryUnchanged() {
        #expect(ids("tokyo") == ["Asia/Tokyo"])
    }
}
