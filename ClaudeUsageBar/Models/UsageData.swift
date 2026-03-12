import Foundation

struct UsageDisplayData {
    var session: SessionUsage?
    var weeklyLimits: WeeklyLimits?
    var extraUsage: ExtraUsage?
    var lastUpdated: Date?
    var error: UsageError?

    var hasAnyData: Bool {
        session != nil || weeklyLimits != nil || extraUsage != nil
    }
}

struct SessionUsage {
    let percentUsed: Double
    let resetTime: Date?

    var displayPercent: String {
        "\(Int(percentUsed))%"
    }
}

struct WeeklyLimits {
    let allModels: ModelLimit?
    let sonnetOnly: ModelLimit?
}

struct ModelLimit {
    let percentUsed: Double
    let resetTime: Date?
    let description: String?

    var displayPercent: String {
        "\(Int(percentUsed))%"
    }
}

struct ExtraUsage {
    let amountSpent: Decimal
    let resetDate: Date?
    let monthlySpendLimit: Decimal?
    let currentBalance: Decimal?
    let autoReloadEnabled: Bool?
}

enum UsageError: LocalizedError {
    case notAuthenticated
    case tokenExpired
    case rateLimited(retryAfter: TimeInterval?)
    case networkError(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Check Settings to add a token."
        case .tokenExpired:
            return "Token expired. Re-authenticate in Claude Code or add a new token."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retrying in \(Int(seconds))s."
            }
            return "Rate limited. Try again later."
        case .networkError(let message):
            return "Network error: \(message)"
        case .parseError(let message):
            return "Failed to parse usage data: \(message)"
        }
    }
}
