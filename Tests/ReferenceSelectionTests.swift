import Foundation
import Testing
@testable import Meridian

/// Changing the reference rebuilds the columns, so a selected hour from the
/// old reference's grid must not linger.
@MainActor
struct ReferenceSelectionTests {
    let london = Place(name: "London", detail: "", timeZoneID: "Europe/London")
    let losAngeles = Place(name: "Los Angeles", detail: "", timeZoneID: "America/Los_Angeles")

    /// A store holding exactly `places`, in that manual order, backed by a
    /// throwaway defaults suite.
    func makeStore(_ places: [Place]) -> PlannerStore {
        let defaults = UserDefaults(suiteName: "MeridianTests-\(UUID())")!
        defaults.set(try! JSONEncoder().encode(places), forKey: "places.v1")
        return PlannerStore(defaults: defaults)
    }

    /// The first column of the shown day.
    func selectFirstSlot(in store: PlannerStore) -> Date {
        let slot = store.slots[0]
        store.selectedSlot = slot
        return slot
    }

    @Test func makingAnotherPlaceTheReferenceClearsTheSelection() {
        let store = makeStore([london, losAngeles])
        _ = selectFirstSlot(in: store)
        store.makeReference(id: losAngeles.id)
        #expect(store.reference.name == "Los Angeles")
        #expect(store.selectedSlot == nil)
    }

    @Test func remakingTheCurrentReferenceKeepsTheSelection() {
        let store = makeStore([london, losAngeles])
        let slot = selectFirstSlot(in: store)
        store.makeReference(id: london.id)
        #expect(store.selectedSlot == slot)
    }

    @Test func makingAnUnknownPlaceTheReferenceKeepsTheSelection() {
        let store = makeStore([london, losAngeles])
        let slot = selectFirstSlot(in: store)
        store.makeReference(id: UUID())
        #expect(store.reference.name == "London")
        #expect(store.selectedSlot == slot)
    }

    @Test func removingTheReferenceClearsTheSelection() {
        let store = makeStore([london, losAngeles])
        _ = selectFirstSlot(in: store)
        store.remove(id: london.id)
        #expect(store.reference.name == "Los Angeles")
        #expect(store.selectedSlot == nil)
    }

    @Test func removingAnotherPlaceKeepsTheSelection() {
        let store = makeStore([london, losAngeles])
        let slot = selectFirstSlot(in: store)
        store.remove(id: losAngeles.id)
        #expect(store.selectedSlot == slot)
    }
}
