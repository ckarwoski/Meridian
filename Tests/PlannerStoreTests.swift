import Foundation
import Testing
@testable import Meridian

@MainActor
struct PlannerStoreTests {
    let pune = Place(name: "Pune", detail: "", timeZoneID: "Asia/Kolkata")
    let slough = Place(name: "Slough", detail: "", timeZoneID: "Europe/London")
    let denver = Place(name: "Denver", detail: "", timeZoneID: "America/Denver")
    let honolulu = Place(name: "Honolulu", detail: "", timeZoneID: "Pacific/Honolulu")

    /// A store holding exactly `places`, in that manual order, backed by a
    /// throwaway defaults suite.
    func makeStore(_ places: [Place]) -> PlannerStore {
        let defaults = UserDefaults(suiteName: "MeridianTests-\(UUID())")!
        defaults.set(try! JSONEncoder().encode(places), forKey: "places.v1")
        return PlannerStore(defaults: defaults)
    }

    @Test func westToEastIsTheDefaultOrder() {
        let store = makeStore([pune, slough, denver, honolulu])
        #expect(store.order == .westToEast)
        #expect(store.orderedPlaces.map(\.name) == ["Honolulu", "Denver", "Slough", "Pune"])
    }

    @Test func referenceDoesNotFollowRowOrder() {
        let store = makeStore([pune, slough, denver])
        #expect(store.reference.name == "Pune")
        #expect(store.orderedPlaces.first?.name == "Denver")
        store.makeReference(id: slough.id)
        #expect(store.reference.name == "Slough")
        #expect(store.orderedPlaces.map(\.name) == ["Denver", "Slough", "Pune"])
    }

    @Test func switchingToManualKeepsTheVisibleOrder() {
        let store = makeStore([pune, slough, denver])
        store.setOrder(.manual)
        #expect(store.orderedPlaces.map(\.name) == ["Denver", "Slough", "Pune"])
    }

    @Test func draggingOntoARowTakesItsPlace() {
        let store = makeStore([denver, slough, pune])
        store.setOrder(.manual)
        store.move(id: pune.id, onto: denver.id)
        #expect(store.orderedPlaces.map(\.name) == ["Pune", "Denver", "Slough"])
        store.move(id: pune.id, onto: slough.id)
        #expect(store.orderedPlaces.map(\.name) == ["Denver", "Slough", "Pune"])
    }

    @Test func movingIsIgnoredWhileSorted() {
        let store = makeStore([denver, slough, pune])
        store.move(id: pune.id, onto: denver.id)
        #expect(store.orderedPlaces.map(\.name) == ["Denver", "Slough", "Pune"])
    }

    @Test func removingTheReferencePicksAnother() {
        let store = makeStore([denver, slough])
        store.remove(id: denver.id)
        #expect(store.reference.name == "Slough")
    }
}
