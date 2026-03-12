import SwiftUI

struct ExtraUsageView: View {
    let extra: ExtraUsage

    private var currencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Extra Usage")
                .font(.headline)

            HStack {
                Text("Spent this period")
                Spacer()
                Text(formatCurrency(extra.amountSpent))
                    .font(.system(.body, design: .monospaced))
            }
            .font(.subheadline)

            if let limit = extra.monthlySpendLimit {
                HStack {
                    Text("Monthly limit")
                    Spacer()
                    Text(formatCurrency(limit))
                        .font(.system(.body, design: .monospaced))
                }
                .font(.subheadline)
            }

            if let balance = extra.currentBalance {
                HStack {
                    Text("Balance")
                    Spacer()
                    Text(formatCurrency(balance))
                        .font(.system(.body, design: .monospaced))
                }
                .font(.subheadline)
            }

            HStack {
                if let autoReload = extra.autoReloadEnabled {
                    Text("Auto-reload: \(autoReload ? "On" : "Off")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let resetDate = extra.resetDate {
                    Spacer()
                    Text("Resets \(resetDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        currencyFormatter.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
}
