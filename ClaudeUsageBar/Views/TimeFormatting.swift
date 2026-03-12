import Foundation

func relativeTimeString(_ date: Date) -> String {
    let now = Date()
    let interval = date.timeIntervalSince(now)

    if interval <= 0 {
        return "soon"
    }

    let totalMinutes = Int(interval / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours >= 24 {
        let days = hours / 24
        let remainingHours = hours % 24
        return "in \(days) day\(days == 1 ? "" : "s") \(remainingHours) hr"
    } else if hours > 0 {
        return "in \(hours) hr \(minutes) min"
    } else if minutes > 0 {
        return "in \(minutes) min"
    } else {
        return "in <1 min"
    }
}
