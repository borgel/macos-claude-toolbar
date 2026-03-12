import Foundation

@MainActor
class UsageAPIClient: ObservableObject {
    @Published var usageData = UsageDisplayData()
    @Published var isFetching = false

    private let authManager: AuthManager
    private let baseURL = "https://api.anthropic.com/api/oauth/usage"
    private let session = URLSession.shared

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func fetchUsage() async {
        guard let token = authManager.token else {
            usageData.error = .notAuthenticated
            return
        }

        isFetching = true
        defer { isFetching = false }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            let httpResponse = response as! HTTPURLResponse

            // Log raw response during development
            if let rawString = String(data: data, encoding: .utf8) {
                print("[API] Status: \(httpResponse.statusCode)")
                print("[API] Response: \(rawString)")
            }

            switch httpResponse.statusCode {
            case 200:
                parseUsageResponse(data)
                usageData.lastUpdated = Date()
                usageData.error = nil

            case 401:
                authManager.markExpired()
                usageData.error = .tokenExpired

            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { TimeInterval($0) }
                usageData.error = .rateLimited(retryAfter: retryAfter)

            default:
                let body = String(data: data, encoding: .utf8) ?? "No body"
                usageData.error = .networkError("HTTP \(httpResponse.statusCode): \(body)")
            }
        } catch {
            usageData.error = .networkError(error.localizedDescription)
        }
    }

    // MARK: - Flexible JSON Parsing

    private func parseUsageResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            usageData.error = .parseError("Invalid JSON")
            return
        }

        // Parse session usage
        if let session = json["session"] as? [String: Any] {
            let percentUsed = session["percentUsed"] as? Double
                ?? session["percent_used"] as? Double
                ?? session["usage_percent"] as? Double
                ?? 0

            var resetTime: Date?
            if let resetStr = session["resetTime"] as? String ?? session["reset_time"] as? String {
                resetTime = parseISO8601(resetStr)
            } else if let resetMs = session["resetTime"] as? Double ?? session["reset_time"] as? Double {
                resetTime = Date(timeIntervalSince1970: resetMs / 1000.0)
            }

            usageData.session = SessionUsage(percentUsed: percentUsed, resetTime: resetTime)
        }

        // Parse weekly limits
        if let weekly = json["weeklyLimits"] as? [String: Any]
            ?? json["weekly_limits"] as? [String: Any]
            ?? json["weekly"] as? [String: Any] {

            let allModels = parseModelLimit(weekly["allModels"] as? [String: Any]
                ?? weekly["all_models"] as? [String: Any])
            let sonnetOnly = parseModelLimit(weekly["sonnetOnly"] as? [String: Any]
                ?? weekly["sonnet_only"] as? [String: Any]
                ?? weekly["sonnet"] as? [String: Any])

            usageData.weeklyLimits = WeeklyLimits(allModels: allModels, sonnetOnly: sonnetOnly)
        }

        // Parse extra usage / billing
        if let extra = json["extraUsage"] as? [String: Any]
            ?? json["extra_usage"] as? [String: Any]
            ?? json["billing"] as? [String: Any] {

            let amountSpent = parseDecimal(extra["amountSpent"] ?? extra["amount_spent"])
            let monthlyLimit = parseDecimal(extra["monthlySpendLimit"] ?? extra["monthly_spend_limit"])
            let balance = parseDecimal(extra["currentBalance"] ?? extra["current_balance"])
            let autoReload = extra["autoReloadEnabled"] as? Bool
                ?? extra["auto_reload_enabled"] as? Bool

            var resetDate: Date?
            if let resetStr = extra["resetDate"] as? String ?? extra["reset_date"] as? String {
                resetDate = parseISO8601(resetStr)
            }

            usageData.extraUsage = ExtraUsage(
                amountSpent: amountSpent ?? 0,
                resetDate: resetDate,
                monthlySpendLimit: monthlyLimit,
                currentBalance: balance,
                autoReloadEnabled: autoReload
            )
        }
    }

    private func parseModelLimit(_ dict: [String: Any]?) -> ModelLimit? {
        guard let dict = dict else { return nil }

        let percentUsed = dict["percentUsed"] as? Double
            ?? dict["percent_used"] as? Double
            ?? 0

        var resetTime: Date?
        if let resetStr = dict["resetTime"] as? String ?? dict["reset_time"] as? String {
            resetTime = parseISO8601(resetStr)
        } else if let resetMs = dict["resetTime"] as? Double ?? dict["reset_time"] as? Double {
            resetTime = Date(timeIntervalSince1970: resetMs / 1000.0)
        }

        let description = dict["description"] as? String

        return ModelLimit(percentUsed: percentUsed, resetTime: resetTime, description: description)
    }

    private func parseDecimal(_ value: Any?) -> Decimal? {
        if let num = value as? Double {
            return Decimal(num)
        } else if let str = value as? String {
            return Decimal(string: str)
        } else if let num = value as? Int {
            return Decimal(num)
        }
        return nil
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
