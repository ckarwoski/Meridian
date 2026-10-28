import Foundation
import Observation

/// How rows are ordered on screen.
enum PlaceOrder: String, CaseIterable, Sendable {
    /// Earliest local time (most negative UTC offset) at the top.
    case westToEast
    /// The user's own order, changed by dragging.
    case manual

    var title: String {
        switch self {
        case .westToEast: "West → East"
        case .manual: "Manual"
        }
    }
}

/// The places being compared and the day being browsed. The reference place
/// sets the columns (its hours) and is what gaps are measured from; it is
/// independent of the row order.
@MainActor @Observable
final class PlannerStore {
    /// In the user's manual order.
    private(set) var places: [Place]
    private(set) var referenceID: Place.ID
    private(set) var order: PlaceOrder
    private(set) var day: CivilDay
    /// The start of the hour the user clicked, if it is on the shown day.
    var selectedSlot: Date?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isFillingCoordinates = false
    @ObservationIgnored private static let placesKey = "places.v1"
    @ObservationIgnored private static let referenceKey = "referenceID.v1"
    @ObservationIgnored private static let orderKey = "placeOrder.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Self.placesKey)
            .flatMap { try? JSONDecoder().decode([Place].self, from: $0) } ?? []
        let initial = stored.isEmpty ? [Place.current()] : stored
        places = initial
        // Before the reference was stored separately, it was the first row.
        let storedReference = defaults.string(forKey: Self.referenceKey).flatMap(UUID.init(uuidString:))
        let reference = initial.first { $0.id == storedReference } ?? initial[0]
        referenceID = reference.id
        order = defaults.string(forKey: Self.orderKey).flatMap(PlaceOrder.init(rawValue:)) ?? .westToEast
        day = CivilDay(.now, in: reference.timeZone)
    }

    var reference: Place { place(id: referenceID) ?? places[0] }
    var referenceZone: TimeZone { reference.timeZone }
    var slots: [Date] { Timeline.slots(on: day, in: referenceZone) }
    var isShowingToday: Bool { day == CivilDay(.now, in: referenceZone) }

    /// The rows as shown. West to east uses each zone's offset on the shown
    /// day, so the order follows daylight saving; ties keep manual order.
    var orderedPlaces: [Place] {
        switch order {
        case .manual:
            return places
        case .westToEast:
            let moment = day.noon(in: referenceZone)
            return places.enumerated()
                .sorted { a, b in
                    let offsetA = a.element.timeZone.secondsFromGMT(for: moment)
                    let offsetB = b.element.timeZone.secondsFromGMT(for: moment)
                    return offsetA != offsetB ? offsetA < offsetB : a.offset < b.offset
                }
                .map(\.element)
        }
    }

    func place(id: Place.ID) -> Place? { places.first { $0.id == id } }

    // MARK: Day

    func show(_ newDay: CivilDay) {
        guard newDay != day else { return }
        day = newDay
        selectedSlot = nil
    }

    func showToday() { show(CivilDay(.now, in: referenceZone)) }
    func shift(days: Int) { show(day.adding(days: days)) }

    // MARK: Places

    func add(_ place: Place) {
        places.append(place)
        save()
    }

    func update(_ place: Place) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index] = place
        save()
    }

    func remove(id: Place.ID) {
        guard places.count > 1 else { return }
        places.removeAll { $0.id == id }
        if referenceID == id { referenceID = places[0].id }
        save()
    }

    /// Looks up coordinates for city places saved before they were kept.
    /// Safe to call from every scene: only the first call does the work.
    func fillMissingCoordinates() async {
        guard !isFillingCoordinates else { return }
        isFillingCoordinates = true
        for place in places where place.latitude == nil && !place.isTimeZoneOnly {
            guard let found = await PlaceSearch.coordinates(for: place), var current = self.place(id: place.id) else { continue }
            current.latitude = found.latitude
            current.longitude = found.longitude
            update(current)
        }
    }

    func makeReference(id: Place.ID) {
        guard place(id: id) != nil else { return }
        referenceID = id
        save()
    }

    func setOrder(_ newOrder: PlaceOrder) {
        guard newOrder != order else { return }
        // Start manual ordering from what's on screen, not a stale order.
        if newOrder == .manual { places = orderedPlaces }
        order = newOrder
        save()
    }

    /// Moves a place one row up (-1) or down (+1). Manual order only.
    func move(id: Place.ID, by step: Int) {
        guard order == .manual, let index = places.firstIndex(where: { $0.id == id }) else { return }
        let target = index + step
        guard places.indices.contains(target) else { return }
        places.swapAt(index, target)
        save()
    }

    /// Moves a dragged place into the row of `targetID`, shifting the rest.
    /// Manual order only.
    func move(id: Place.ID, onto targetID: Place.ID) {
        guard order == .manual, id != targetID,
              let from = places.firstIndex(where: { $0.id == id }),
              let to = places.firstIndex(where: { $0.id == targetID }) else { return }
        places.insert(places.remove(at: from), at: to)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(places) {
            defaults.set(data, forKey: Self.placesKey)
        }
        defaults.set(referenceID.uuidString, forKey: Self.referenceKey)
        defaults.set(order.rawValue, forKey: Self.orderKey)
    }
}
