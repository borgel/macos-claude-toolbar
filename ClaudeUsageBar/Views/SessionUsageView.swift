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