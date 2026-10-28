import Foundation

/// How light it is outside.
enum Daylight: Sendable {
    case day
    /// Sun below the horizon but less than 6° down: dawn or dusk.
    case twilight
    case night

    init(sunElevation degrees: Double) {
        if degrees >= -0.833 { self = .day } else if degrees >= -6 { self = .twilight } else { self = .night }
    }
}

/// The sun's position from the low-precision formulas in the Astronomical
/// Almanac; good to about a degree, which is plenty for shading.
enum Solar {
    /// Degrees above the horizon (negative: below) at `date` for a place.
    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let days = date.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545.0
        let meanAnomaly = radians(357.529 + 0.98560028 * days)
        let meanLongitude = 280.459 + 0.98564736 * days
        let eclipticLongitude = radians(meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly))
        let obliquity = radians(23.439 - 0.00000036 * days)

        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let siderealDegrees = (18.697374558 + 24.06570982441908 * days) * 15
        let hourAngle = radians(siderealDegrees + longitude) - rightAscension

        let lat = radians(latitude)
        let sine = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)
        return asin(sine) * 180 / .pi
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
}
