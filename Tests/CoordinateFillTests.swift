import Foundation
import Testing
@testable import Meridian

/// What a fake lookup has been asked, and what it should answer.
@MainActor
final class FakeLookup {
    var online = true
    var looked: [String] = []
    var time = Date.now
    /// If set, each lookup waits here until resumed.
    var release: CheckedContinuation<Void, Never>?
    var waits = false
    var cancelsCaller = false
}

@MainActor
struct CoordinateFillTests {
    let slough = Place(name: "Slough", detail: "England, United Kingdom", timeZoneID: "Europe/London")
    let denver = Place(name: "Denver", detail: "Colorado, United States", timeZoneID: "America/Denver")
    let utc = Place(name: "UTC", detail: "UTC · GMT+0", timeZoneID: "UTC")

    /// A store holding exactly `places`, backed by a throwaway defaults suite,
    /// that looks coordinates up and reads the time from `fake`.
    func makeStore(_ places: [Place], _ fake: FakeLookup) -> PlannerStore {
        let defaults = UserDefaults(suiteName: "MeridianTests-\(UUID())")!
        defaults.set(try! JSONEncoder().encode(places), forKey: "places.v1")
        return PlannerStore(
            defaults: defaults,
            lookUpCoordinates: { place in
                fake.looked.append(place.name)
                if fake.cancelsCaller { withUnsafeCurrentTask { $0?.cancel() } }
                if fake.waits { await withCheckedContinuation { fake.release = $0 } }
                return fake.online ? (51.5, -0.6) : nil
            },
            now: { fake.time }
        )
    }

    @Test func aFailedPassIsRetriedByALaterCall() async {
        let fake = FakeLookup()
        fake.online = false
        let store = makeStore([slough], fake)
        await store.fillMissingCoordinates()
        #expect(store.places[0].latitude == nil)
        fake.online = true
        fake.time += 3 * 60
        await store.fillMissingCoordinates()
        #expect(store.places[0].latitude == 51.5)
        #expect(store.places[0].longitude == -0.6)
    }

    @Test func retriesWaitTwoMinutesAfterAPass() async {
        let fake = FakeLookup()
        fake.online = false
        let store = makeStore([slough], fake)
        await store.fillMissingCoordinates()
        await store.fillMissingCoordinates()
        fake.time += 119
        await store.fillMissingCoordinates()
        #expect(fake.looked.count == 1)
        fake.time += 1
        await store.fillMissingCoordinates()
        #expect(fake.looked.count == 2)
    }

    @Test func onlyOnePassRunsAtATime() async {
        let fake = FakeLookup()
        fake.waits = true
        let store = makeStore([slough], fake)
        let first = Task { await store.fillMissingCoordinates() }
        while fake.release == nil { await Task.yield() }
        await store.fillMissingCoordinates()
        #expect(fake.looked.count == 1)
        fake.release?.resume()
        await first.value
        #expect(store.places[0].latitude == 51.5)
    }

    @Test func cancellingStopsThePassAndAllowsARetry() async {
        let fake = FakeLookup()
        fake.online = false
        fake.cancelsCaller = true
        let store = makeStore([slough, denver], fake)
        await Task { await store.fillMissingCoordinates() }.value
        #expect(fake.looked == ["Slough"])
        await Task { await store.fillMissingCoordinates() }.value
        #expect(fake.looked == ["Slough", "Slough"])
    }

    @Test func cancellingDuringTheOnlyLookupAllowsARetry() async {
        let fake = FakeLookup()
        fake.online = false
        fake.cancelsCaller = true
        let store = makeStore([slough], fake)
        await Task { await store.fillMissingCoordinates() }.value
        await Task { await store.fillMissingCoordinates() }.value
        #expect(fake.looked == ["Slough", "Slough"])
    }

    @Test func nothingIsLookedUpWhenNoPlaceNeedsIt() async {
        var located = denver
        located.latitude = 39.7
        located.longitude = -105
        let fake = FakeLookup()
        let store = makeStore([located, utc], fake)
        await store.fillMissingCoordinates()
        #expect(fake.looked.isEmpty)
    }
}
