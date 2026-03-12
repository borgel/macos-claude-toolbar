import SwiftUI

struct UsageProgressBar: View {
    let percent: Double
    var height: CGFloat = 8

    private var color: Color {
        switch percent {
        case 90...: return .red
        case 70..<90: return .orange
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
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * clampedPercent / 100)
            }
        }
        .frame(height: height)
    }
}
