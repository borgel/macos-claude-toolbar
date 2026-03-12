import SwiftUI

struct SessionUsageView: View {
    let session: SessionUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Session Usage")
                .font(.headline)

            HStack {
                UsageProgressBar(percent: session.percentUsed)
                Text(session.displayPercent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }

            if let resetTime = session.resetTime {
                Text("Resets \(relativeTimeString(resetTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private func relativeTimeString(_ date: Date) -> String {
    let now = Date()
    let interval = date.timeIntervalSince(now)

    if interval <= 0 {
        return "soon"
    }

    let totalMinutes = Int(interval / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 {
        return "in \(hours) hr \(minutes) min"
    } else {
        return "in \(minutes) min"
    }
}
