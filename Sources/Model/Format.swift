import Foundation

enum Format {
    /// Whether the user's locale prefers a 24-hour clock.
    static var localePrefers24Hour: Bool {
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "H"
        return !pattern.contains("a")
    }

    /// "15:30" or "3:30 pm".
    static func time(_ date: Date, in zone: TimeZone, use24Hour: Bool) -> String {
        let parts = Calendar.gregorian(in: zone).dateComponents([.hour, .minute], from: date)
        return time(hour: parts.hour ?? 0, minute: parts.minute ?? 0, use24Hour: use24Hour)
    }

    static func time(minuteOfDay: Int, use24Hour: Bool) -> String {
        time(hour: minuteOfDay / 60 % 24, minute: minuteOfDay % 60, use24Hour: use24Hour)
    }

    static func time(hour: Int, minute: Int, use24Hour: Bool) -> String {
        let mm = String(format: "%02d", minute)
        if use24Hour { return String(format: "%02d", hour) + ":" + mm }
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h):\(mm) \(hour < 12 ? "am" : "pm")"
    }

    /// The compact label in a grid cell: "15" / "3p", with minutes only for
    /// zones on a half or quarter hour.
    static func cellHour(_ date: Date, in zone: TimeZone, use24Hour: Bool) -> (hour: String, minute: String?) {
        let parts = Calendar.gregorian(in: zone).dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let minuteText = minute == 0 ? nil : String(format: ":%02d", minute)
        if use24Hour { return (String(hour), minuteText) }
        let h = hour % 12 == 0 ? 12 : hour % 12
        return ("\(h)\(hour < 12 ? "a" : "p")", minuteText)
    }

    /// "Thu 29 Oct".
    static func shortDay(_ date: Date, in zone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "Thursday, 29 October 2026".
    static func longDay(_ date: Date, in zone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(timeZone: zone).weekday(.wide).day().month(.wide).year())
    }

    /// "+5h", "−3h30", "±0".
    static func offset(_ seconds: Int) -> String {
        if seconds == 0 { return "±0" }
        let sign = seconds > 0 ? "+" : "−"
        let minutes = abs(seconds) / 60
        let rest = minutes % 60
        return rest == 0 ? "\(sign)\(minutes / 60)h" : "\(sign)\(minutes / 60)h\(String(format: "%02d", rest))"
    }

    /// "1 hour", "30 minutes".
    static func duration(_ seconds: Int) -> String {
        let minutes = abs(seconds) / 60
        if minutes % 60 == 0 { return minutes == 60 ? "1 hour" : "\(minutes / 60) hours" }
        return "\(minutes) minutes"
    }

    /// "MDT", "CET", or "UTC+1" where the system has no letters for the
    /// zone in this locale (it would say "GMT+1").
    static func zoneAbbreviation(_ zone: TimeZone, at date: Date) -> String {
        if let abbreviation = zone.abbreviation(for: date), !abbreviation.hasPrefix("GMT") || abbreviation == "GMT" {
            return abbreviation
        }
        return utcOffset(zone.secondsFromGMT(for: date))
    }

    /// "UTC+1", "UTC−5:30".
    static func utcOffset(_ seconds: Int) -> String {
        if seconds == 0 { return "UTC" }
        let sign = seconds > 0 ? "+" : "−"
        let minutes = abs(seconds) / 60
        let rest = minutes % 60
        return "UTC\(sign)\(minutes / 60)" + (rest == 0 ? "" : String(format: ":%02d", rest))
    }
}
