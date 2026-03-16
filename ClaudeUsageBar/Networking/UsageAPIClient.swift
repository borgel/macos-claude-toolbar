import Foundation

private func debugLog(_ message: String) {
    let entry = "\(Date()): \(message)\n"
    let path = "/tmp/claude_usage_debug.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(entry.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? entry.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

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
        debugLog("fetchUsage called, authState=\(authManager.state)")

        // Ensure we have a valid token, refreshing if expired
        await authManager.ensureAuthenticated()

        guard let token = authManager.token else {
            debugLog("No token available")
            usageData.error = .notAuthenticated
            return
        }

        debugLog("Have token: \(String(token.prefix(20)))...")
        isFetching = true
        defer { isFetching = false }

        let (statusCode, data) = await performRequest(token: token)
        guard let statusCode = statusCode, let data = data else { return }

        switch statusCode {
        case 200:
            parseUsageResponse(data)
            usageData.lastUpdated = Date()
            usageData.error = nil

        case 401:
            // Token rejected by server — attempt refresh and retry once
            debugLog("Got 401, attempting token refresh...")
            await authManager.refreshClaudeCodeTokenIfNeeded()
            if let newToken = authManager.token, newToken != token {
                debugLog("Retrying with refreshed token")
                let (retryStatus, retryData) = await performRequest(token: newToken)
                guard let retryStatus = retryStatus, let retryData = retryData else { return }
                if retryStatus == 200 {
                    parseUsageResponse(retryData)
                    usageData.lastUpdated = Date()
                    usageData.error = nil
                } else {
                    authManager.markExpired()
                    usageData.error = .tokenExpired
                }
            } else {
                authManager.markExpired()
                usageData.error = .tokenExpired
            }

        case 429:
            let retryAfter = lastRetryAfter
            usageData.error = .rateLimited(retryAfter: retryAfter)

        default:
            let body = String(data: data, encoding: .utf8) ?? "No body"
            usageData.error = .networkError("HTTP \(statusCode): \(body)")
        }
    }

    /// Tracks Retry-After from the most recent response (used across helper calls)
    private var lastRetryAfter: TimeInterval?

    /// Perform a single API request with the given token. Returns (statusCode, data) or sets error and returns nils.
    private func performRequest(token: String) async -> (Int?, Data?) {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)
            let httpResponse = response as! HTTPURLResponse

            if let rawString = String(data: data, encoding: .utf8) {
                debugLog("Status: \(httpResponse.statusCode)")
                debugLog("Response: \(rawString)")
                try? rawString.write(toFile: "/tmp/claude_usage_response.json", atomically: true, encoding: .utf8)
            }

            lastRetryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }

            return (httpResponse.statusCode, data)
        } catch {
            debugLog("Network error: \(error)")
            usageData.error = .networkError(error.localizedDescription)
            return (nil, nil)
        }
    }

    // MARK: - JSON Parsing
    //
    // Actual API response format:
    // {
    //   "five_hour": { "utilization": 61.0, "resets_at": "2026-03-13T00:00:00.742888+00:00" },
    //   "seven_day": { "utilization": 29.0, "resets_at": "..." },
    //   "seven_day_sonnet": { "utilization": 0.0, "resets_at": null },
    //   "seven_day_opus": null,
    //   "seven_day_oauth_apps": null,
    //   "seven_day_cowork": null,
    //   "extra_usage": { "is_enabled": true, "monthly_limit": 5000, "used_credits": 0.0, "utilization": null }
    // }

    private func parseUsageResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            usageData.error = .parseError("Invalid JSON")
            return
        }

        debugLog("Parsing keys: \(json.keys.sorted())")

        // five_hour → session usage
        if let fiveHour = json["five_hour"] as? [String: Any] {
            let utilization = fiveHour["utilization"] as? Double ?? 0
            let resetTime = (fiveHour["resets_at"] as? String).flatMap { parseISO8601($0) }
            usageData.session = SessionUsage(percentUsed: utilization, resetTime: resetTime)
            debugLog("Parsed session: \(utilization)%")
        }

        // seven_day + seven_day_sonnet → weekly limits
        let sevenDay = json["seven_day"] as? [String: Any]
        let sevenDaySonnet = json["seven_day_sonnet"] as? [String: Any]

        if sevenDay != nil || sevenDaySonnet != nil {
            let allModels = parseUtilizationEntry(sevenDay, description: "All Models")
            let sonnetOnly = parseUtilizationEntry(sevenDaySonnet, description: "Sonnet Only")
            usageData.weeklyLimits = WeeklyLimits(allModels: allModels, sonnetOnly: sonnetOnly)
            debugLog("Parsed weekly: allModels=\(allModels?.percentUsed ?? -1), sonnet=\(sonnetOnly?.percentUsed ?? -1)")
        }

        // extra_usage → billing
        if let extra = json["extra_usage"] as? [String: Any] {
            let usedCredits = extra["used_credits"] as? Double ?? 0
            let monthlyLimit = extra["monthly_limit"] as? Double
            let isEnabled = extra["is_enabled"] as? Bool

            usageData.extraUsage = ExtraUsage(
                amountSpent: Decimal(usedCredits),
                resetDate: nil,
                monthlySpendLimit: monthlyLimit.map { Decimal($0) },
                currentBalance: nil,
                autoReloadEnabled: isEnabled
            )
            debugLog("Parsed extra: spent=\(usedCredits), limit=\(monthlyLimit ?? -1)")
        }
    }

    private func parseUtilizationEntry(_ dict: [String: Any]?, description: String) -> ModelLimit? {
        guard let dict = dict else { return nil }
        let utilization = dict["utilization"] as? Double ?? 0
        let resetTime = (dict["resets_at"] as? String).flatMap { parseISO8601($0) }
        return ModelLimit(percentUsed: utilization, resetTime: resetTime, description: description)
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
