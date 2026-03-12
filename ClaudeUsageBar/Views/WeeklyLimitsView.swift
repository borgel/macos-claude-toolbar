import SwiftUI

struct WeeklyLimitsView: View {
    let limits: WeeklyLimits

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weekly Limits")
                .font(.headline)

            if let allModels = limits.allModels {
                modelLimitRow(label: allModels.description ?? "All Models", limit: allModels)
            }

            if let sonnet = limits.sonnetOnly {
                modelLimitRow(label: sonnet.description ?? "Sonnet Only", limit: sonnet)
            }
        }
    }

    @ViewBuilder
    private func modelLimitRow(label: String, limit: ModelLimit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(limit.displayPercent)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            UsageProgressBar(percent: limit.percentUsed, height: 6)

            if let resetTime = limit.resetTime {
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
