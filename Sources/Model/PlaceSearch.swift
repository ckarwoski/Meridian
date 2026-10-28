import Foundation
import MapKit
import Observation

/// Finds places by name. Cities and towns come from MapKit, so "Slough" is
/// Slough (in Europe/London), not London. Time zone identifiers and names are
/// matched locally too, for "UTC", "Pacific Time" and offline use.
@MainActor @Observable
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var completions: [MKLocalSearchCompletion] = []
    private(set) var zoneMatches: [Place] = []
    private(set) var failed = false

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    /// The trimmed query that `completions` must belong to.
    @ObservationIgnored private var currentQuery = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // Towns and cities only: street names aren't useful here.
        completer.addressFilter = MKAddressFilter(including: [.locality, .subLocality, .subAdministrativeArea])
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        failed = false
        zoneMatches = Self.zones(matching: trimmed)
        // Drop the old query's places now rather than when MapKit replies, so
        // Return can't add London after the field changes to "UTC".
        let changed = trimmed != currentQuery
        if changed { completions = [] }
        currentQuery = trimmed
        if trimmed.isEmpty {
            // Don't blank queryFragment here: that fails later with an error
            // that would land on the next query.
            completer.cancel()
        } else {
            // cancel() keeps the old fragment, and setting the same fragment
            // again starts no search, so clearing and retyping "London" would
            // leave Places empty. Nudge it so a new search runs.
            if changed && completer.queryFragment == trimmed { completer.queryFragment = "" }
            completer.queryFragment = trimmed
        }
    }

    /// Looks up the completion's time zone and returns it as a place.
    func resolve(_ completion: MKLocalSearchCompletion) async throws -> Place {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .address
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first(where: { $0.timeZone != nil }), let zone = item.timeZone else {
            throw SearchError.noTimeZone
        }
        let name = item.name ?? completion.title
        let coordinate = item.location.coordinate
        return Place(
            name: name,
            detail: completion.subtitle,
            timeZoneID: zone.identifier,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    /// Finds coordinates for a place saved without them, by searching its
    /// name. Only accepts a match in the place's own time zone, so a
    /// same-named town elsewhere can't paint the wrong daylight.
    static func coordinates(for place: Place) async -> (latitude: Double, longitude: Double)? {
        let request = MKLocalSearch.Request()
        let hasRegion = !place.detail.isEmpty && place.detail != Place.current().detail
        request.naturalLanguageQuery = hasRegion ? "\(place.name), \(place.detail)" : place.name
        request.resultTypes = .address
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first(where: { $0.timeZone?.identifier == place.timeZoneID }) else {
            return nil
        }
        let coordinate = item.location.coordinate
        return (coordinate.latitude, coordinate.longitude)
    }

    enum SearchError: LocalizedError {
        case noTimeZone
        var errorDescription: String? { "MapKit didn't return a time zone for that place." }
    }

    /// Takes completer results unless the field is empty, so a late reply
    /// can't repopulate a cleared field. The completer can't say which query
    /// a reply answers, so one for an earlier non-empty query still gets in.
    func accept(_ results: [MKLocalSearchCompletion]) {
        guard !currentQuery.isEmpty else { return }
        completions = Array(results.prefix(8))
    }

    func fail() {
        guard !currentQuery.isEmpty else { return }
        completions = []
        failed = true
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            accept(self.completer.results)
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            fail()
        }
    }

    static func zones(matching query: String) -> [Place] {
        guard query.count >= 2 else { return [] }
        let underscored = query.replacing(" ", with: "_")
        var identifiers = TimeZone.knownTimeZoneIdentifiers.filter { identifier in
            if identifier.localizedCaseInsensitiveContains(underscored) { return true }
            let zone = TimeZone(identifier: identifier)
            if zone?.localizedName(for: .generic, locale: .current)?.localizedCaseInsensitiveContains(query) == true { return true }
            return zone?.abbreviation()?.caseInsensitiveCompare(query) == .orderedSame
        }
        // Offer UTC only for a prefix of its abbreviation or full name, so
        // "time" or "in" don't pin it to the top. Three letters for the full
        // name, so "co" stays a city search.
        func starts(_ name: String) -> Bool {
            name.range(of: query, options: [.anchored, .caseInsensitive]) != nil
        }
        let meansUTC = starts("UTC") || (query.count >= 3 && (starts("Coordinated Universal Time") || starts("Universal Time")))
        if meansUTC {
            identifiers.removeAll { $0 == "UTC" }
            identifiers.insert("UTC", at: 0)
        }
        return identifiers.prefix(6).map { identifier in
            let zone = TimeZone(identifier: identifier)
            let generic = zone?.localizedName(for: .generic, locale: .current) ?? identifier
            return Place(name: Place.cityName(of: identifier), detail: "\(generic) · \(identifier)", timeZoneID: identifier)
        }
    }
}
