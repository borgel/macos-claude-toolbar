import Foundation

enum AuthSource: String {
    case claudeCode = "Claude Code (Keychain)"
    case manual = "Manual Token"
}

enum AuthState: Equatable {
    case notAuthenticated
    case authenticated(token: String, source: AuthSource)
    case expired
    case error(String)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.notAuthenticated, .notAuthenticated): return true
        case (.expired, .expired): return true
        case let (.authenticated(t1, s1), .authenticated(t2, s2)): return t1 == t2 && s1 == s2
        case let (.error(m1), .error(m2)): return m1 == m2
        default: return false
        }
    }
}

@MainActor
class AuthManager: ObservableObject {
    @Published var state: AuthState = .notAuthenticated

    private static let tokenURL = "https://platform.claude.com/v1/oauth/token"
    private static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    /// The current access token, if authenticated.
    var token: String? {
        if case .authenticated(let token, _) = state {
            return token
        }
        return nil
    }

    /// Try to resolve credentials: Claude Code keychain first, then manual token.
    func resolveCredentials() {
        // Try Claude Code's OAuth token first
        if let creds = KeychainHelper.readClaudeCodeToken() {
            // Check expiration
            if let expiresAt = creds.expiresAt, expiresAt < Date() {
                print("[Auth] Claude Code token expired at \(expiresAt)")
                // Fall through to try manual token
            } else {
                print("[Auth] Using Claude Code OAuth token (expires: \(creds.expiresAt?.description ?? "unknown"))")
                state = .authenticated(token: creds.accessToken, source: .claudeCode)
                return
            }
        }

        // Try manual token
        if let manualToken = KeychainHelper.readManualToken(), !manualToken.isEmpty {
            print("[Auth] Using manually entered token")
            state = .authenticated(token: manualToken, source: .manual)
            return
        }

        print("[Auth] No credentials found")
        state = .notAuthenticated
    }

    /// Ensure we have a valid token, attempting to refresh an expired Claude Code token if needed.
    func ensureAuthenticated() async {
        // First, do a synchronous check
        resolveCredentials()

        // If we got a valid token, we're done
        if token != nil { return }

        // If not authenticated, try refreshing the Claude Code token
        await refreshClaudeCodeTokenIfNeeded()
    }

    /// Attempt to refresh an expired Claude Code OAuth token using the refresh token.
    /// Updates the Keychain and auth state on success.
    func refreshClaudeCodeTokenIfNeeded() async {
        guard let creds = KeychainHelper.readClaudeCodeToken(),
              let refreshToken = creds.refreshToken else {
            print("[Auth] No Claude Code credentials or refresh token available")
            return
        }

        // Only refresh if the token is actually expired (or within 60s of expiring)
        if let expiresAt = creds.expiresAt, expiresAt > Date().addingTimeInterval(60) {
            return
        }

        print("[Auth] Attempting to refresh Claude Code OAuth token...")

        do {
            let newTokens = try await performTokenRefresh(refreshToken: refreshToken)

            // Compute new expiration from expires_in (seconds)
            let newExpiresAt: Date?
            if let expiresIn = newTokens.expiresIn {
                newExpiresAt = Date().addingTimeInterval(expiresIn)
            } else {
                newExpiresAt = nil
            }

            // Update the Keychain with fresh tokens
            let updated = KeychainHelper.updateClaudeCodeToken(
                accessToken: newTokens.accessToken,
                refreshToken: newTokens.refreshToken,
                expiresAt: newExpiresAt
            )

            if updated {
                print("[Auth] Token refresh successful (expires: \(newExpiresAt?.description ?? "unknown"))")
                state = .authenticated(token: newTokens.accessToken, source: .claudeCode)
            } else {
                print("[Auth] Token refresh succeeded but failed to update Keychain")
                // Use the new token for this session even if Keychain write failed
                state = .authenticated(token: newTokens.accessToken, source: .claudeCode)
            }
        } catch {
            print("[Auth] Token refresh failed: \(error)")
            // Leave state as-is; resolveCredentials already set it
        }
    }

    /// Save a manually-entered token and update state.
    func setManualToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            KeychainHelper.deleteManualToken()
            resolveCredentials()
            return
        }

        if KeychainHelper.saveManualToken(trimmed) {
            state = .authenticated(token: trimmed, source: .manual)
        } else {
            state = .error("Failed to save token to Keychain")
        }
    }

    /// Clear manual token and re-resolve.
    func clearManualToken() {
        KeychainHelper.deleteManualToken()
        resolveCredentials()
    }

    /// Mark the current token as expired and try to re-resolve.
    func markExpired() {
        state = .expired
        // Try to find another valid token
        resolveCredentials()
    }

    // MARK: - Token Refresh HTTP Call

    private struct TokenRefreshResponse {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: TimeInterval?
    }

    private func performTokenRefresh(refreshToken: String) async throws -> TokenRefreshResponse {
        let url = URL(string: Self.tokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TokenRefreshError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw TokenRefreshError.invalidResponse
        }

        let newRefreshToken = json["refresh_token"] as? String
        let expiresIn = json["expires_in"] as? TimeInterval

        return TokenRefreshResponse(
            accessToken: accessToken,
            refreshToken: newRefreshToken,
            expiresIn: expiresIn
        )
    }

    private enum TokenRefreshError: LocalizedError {
        case httpError(statusCode: Int, body: String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .httpError(let code, let body): return "Token refresh HTTP \(code): \(body)"
            case .invalidResponse: return "Invalid token refresh response"
            }
        }
    }
}
