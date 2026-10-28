import Foundation

/// A location someone works from. The name is whatever the user searched for
/// ("Slough"), independent of the time zone's own city ("London").
struct Place: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    /// Region and country, e.g. "England, United Kingdom".
    var detail: String
    var timeZoneID: String
    /// Free text, typically who is there ("Priya, Tom").
    var note: String = ""
    /// Working day as minutes after local midnight. End may be before start
    /// for overnight shifts.
    var workStart: Int = 9 * 60
    var workEnd: Int = 17 * 60
    /// Where the place is, for daylight shading. Missing for places added
    /// by time zone name, and for places saved before coordinates were kept.
    var latitude: Double?
    var longitude: Double?

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// A place for the Mac's own time zone, named after the zone's city.
    static func current() -> Place {
        let zone = TimeZone.current
        return Place(name: cityName(of: zone.identifier), detail: "Your time zone", timeZoneID: zone.identifier)
    }

    /// "America/Argentina/Buenos_Aires" → "Buenos Aires".
    static func cityName(of identifier: String) -> String {
        let last = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return last.replacing("_", with: " ")
    }
}

extension Place {
    /// Whether the place was added from a bare time zone rather than a city.
    var isTimeZoneOnly: Bool { detail.contains(" · ") }

    func daylight(at date: Date) -> Daylight? {
        guard let latitude, let longitude else { return nil }
        return Daylight(sunElevation: Solar.elevation(at: date, latitude: latitude, longitude: longitude))
    }
}

enum Availability: Sendable {
    case working
    /// Within a couple of hours of the working day: possible, not ideal.
    case shoulder
    case night
}

extension Place {
    static let shoulderMinutes = 120

    func localMinuteOfDay(at date: Date) -> Int {
        let parts = Calendar.gregorian(in: timeZone).dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    func availability(at date: Date) -> Availability {
        let minute = localMinuteOfDay(at: date)
        if Self.contains(minute, from: workStart, to: workEnd) { return .working }
        // No working day means no shoulders either.
        if workStart == workEnd { return .night }
        // Check each shoulder on its own: widening the whole window instead
        // makes the ends cross when the off-duty gap is four hours or less.
        let before = (workStart - Self.shoulderMinutes + 1440) % 1440
        let after = (workEnd + Self.shoulderMinutes) % 1440
        if Self.contains(minute, from: before, to: workStart) || Self.contains(minute, from: workEnd, to: after) {
            return .shoulder
        }
        return .night
    }

    /// Whether `minute` is in the half-open daily window [from, to), which
    /// wraps past midnight when `to` < `from`.
    static func contains(_ minute: Int, from: Int, to: Int) -> Bool {
        if from == to { return false }
        if from < to { return minute >= from && minute < to }
        return minute >= from || minute < to
    }
}

extension Calendar {
    static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
