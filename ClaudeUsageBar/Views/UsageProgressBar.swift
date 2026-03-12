import SwiftUI

struct UsageProgressBar: View {
    let percent: Double
    var height: CGFloat = 8
    @AppStorage("redThresholdPercent") private var redThreshold: Double = 90

    private var isAlert: Bool {
        percent >= redThreshold
    }

    private var color: Color {
        switch percent {
        case redThreshold...: return .red
        case (redThreshold - 20)..<redThreshold: return .orange
        default: return .blue
        }
    }

    private var clampedPercent: Double {
        min(max(percent, 0), 100)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(isAlert ? 0.75 : 0.2))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * clampedPercent / 100)
            }
        }
        .frame(height: height)
    }
}
