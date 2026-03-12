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