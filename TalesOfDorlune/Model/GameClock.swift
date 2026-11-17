import Foundation

/// Fairyland Online's calendar ("1001/Fire/12/13hr"): by day an in-game hour passes every real minute,
/// and each 60-day month belongs to one of the five elements. Night (18hr to 6hr) runs at
/// `nightPace`, so it's over in eight real minutes rather than twelve.
enum GameClock {
    static let months: [Element] = [.metal, .wood, .water, .fire, .earth]
    /// In-game hours that pass in a real minute by day: two and a half real minutes an hour, so
    /// daylight lasts half an hour (the user, 2026-11-14: "the time goes too fast"; at an hour a
    /// minute the trees' shade swung round as you watched).
    static let dayPace = 0.4
    /// In-game hours that pass in a real minute at night.
    static let nightPace = 1.5
    /// Real minutes of daylight, and in an in-game day: daylight, then the night at its pace.
    static let daylightMinutes = 12 / dayPace
    static let dayMinutes = daylightMinutes + 12 / nightPace
    /// Where the calendar begins for a save that doesn't say.
    static let origin = Date(timeIntervalSince1970: 1_790_000_000)
    /// Debug launches with `hour=` only (`DebugLaunch`): the clock stands still from this moment, so a
    /// screenshot shows the hour it asked for. Night lasts eight real minutes, and on the CI simulator the
    /// lands took longer than that to build: `hour=23` was morning by the time it was shot.
    nonisolated(unsafe) static var frozenAt: Date?

    struct Moment {
        let year: Int
        let month: Element
        let day: Int
        let hour: Int

        var isDaytime: Bool { (6..<18).contains(hour) }
        var text: String { L("{year}/{month}/{day}/{hour}hr", ["year": year, "month": month.displayName, "day": day, "hour": hour]) }
    }

    static func moment(at date: Date = Date(), since start: Date?) -> Moment {
        let hours = Int(self.hours(at: date, since: start))
        let days = hours / 24
        return Moment(year: 1001 + days / 300, month: months[(days / 60) % months.count], day: days % 60 + 1, hour: hours % 24)
    }

    /// In-game hours since the calendar began, with the minutes as a fraction (for light that
    /// changes smoothly through the day). The hour of the day is this modulo 24.
    static func hours(at date: Date = Date(), since start: Date?) -> Double {
        let origin = start ?? Self.origin
        let date = frozenAt ?? date
        // A new game opens mid-morning on day one, 9hr: three daylight hours after dawn.
        let sinceDawn = max(0, date.timeIntervalSince(origin) / 60) + 3 / dayPace
        let days = (sinceDawn / dayMinutes).rounded(.down)
        let into = sinceDawn - days * dayMinutes
        return days * 24 + (into < daylightMinutes ? 6 + into * dayPace : 18 + (into - daylightMinutes) * nightPace)
    }

    /// Real minutes from a new game's 9hr until the clock first reads `hour` (0-23), for debug
    /// launches that start at a given time of day.
    static func minutes(untilHour hour: Int) -> Double {
        let sinceDawn = Double((hour - 6 + 24) % 24)
        let real = sinceDawn <= 12 ? sinceDawn / dayPace : daylightMinutes + (sinceDawn - 12) / nightPace
        return (real - 3 / dayPace + dayMinutes).truncatingRemainder(dividingBy: dayMinutes)
    }

    /// Real minutes of the clock a trip behind the loading card skips at in-game `hour` (0..<24): an
    /// hour by day, three at night (the user, 2026-11-14: through a cave's mouth, a feather or a
    /// shard, "you jump in time and it's not too long dark"). `GameSession.skipTimeOnTravel`.
    static func skippedMinutes(atHour hour: Double) -> Double {
        (6..<18).contains(hour) ? 1 / dayPace : 3 / nightPace
    }
}
