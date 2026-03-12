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
}
