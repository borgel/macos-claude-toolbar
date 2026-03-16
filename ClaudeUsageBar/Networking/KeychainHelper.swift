import Foundation
import Security

enum KeychainHelper {
    // MARK: - Claude Code Credential Reading

    private static let claudeCodeService = "Claude Code-credentials"
    private static let appService = "com.borgel.ClaudeUsageBar"

    struct ClaudeCodeCredentials {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date?
    }

    /// Read Claude Code's OAuth token from the macOS Keychain.
    static func readClaudeCodeToken() -> ClaudeCodeCredentials? {
        let account = NSUserName()
        guard let data = readKeychainItem(service: claudeCodeService, account: account) else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String else {
            return nil
        }

        let refreshToken = oauth["refreshToken"] as? String
        var expiresAt: Date?
        if let expiresMs = oauth["expiresAt"] as? Double {
            expiresAt = Date(timeIntervalSince1970: expiresMs / 1000.0)
        }

        return ClaudeCodeCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )
    }

    // MARK: - Claude Code Token Update (after refresh)

    /// Update the Claude Code OAuth token in the Keychain after a successful refresh.
    static func updateClaudeCodeToken(accessToken: String, refreshToken: String?, expiresAt: Date?) -> Bool {
        let account = NSUserName()

        // Read existing keychain data to preserve other fields
        guard let existingData = readKeychainItem(service: claudeCodeService, account: account),
              var json = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any],
              var oauth = json["claudeAiOauth"] as? [String: Any] else {
            print("[Keychain] Cannot update Claude Code token: failed to read existing entry")
            return false
        }

        oauth["accessToken"] = accessToken
        if let refreshToken = refreshToken {
            oauth["refreshToken"] = refreshToken
        }
        if let expiresAt = expiresAt {
            oauth["expiresAt"] = expiresAt.timeIntervalSince1970 * 1000.0
        }

        json["claudeAiOauth"] = oauth

        guard let updatedData = try? JSONSerialization.data(withJSONObject: json) else {
            print("[Keychain] Failed to serialize updated token data")
            return false
        }

        // Delete and re-add (Keychain doesn't have a great update API)
        deleteKeychainItem(service: claudeCodeService, account: account)
        return addKeychainItem(service: claudeCodeService, account: account, data: updatedData)
    }

    // MARK: - App's Own Token Storage

    /// Save a manually-entered token to the app's own Keychain entry.
    static func saveManualToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        deleteKeychainItem(service: appService, account: "manualToken")
        return addKeychainItem(service: appService, account: "manualToken", data: data)
    }

    /// Read the manually-entered token.
    static func readManualToken() -> String? {
        guard let data = readKeychainItem(service: appService, account: "manualToken") else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Delete the manually-entered token.
    static func deleteManualToken() {
        deleteKeychainItem(service: appService, account: "manualToken")
    }

    // MARK: - Low-Level Keychain Operations

    private static func readKeychainItem(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                print("[Keychain] Read error for service=\(service): \(status)")
            }
            return nil
        }

        return data
    }

    private static func addKeychainItem(service: String, account: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Keychain] Add error for service=\(service): \(status)")
        }
        return status == errSecSuccess
    }

    @discardableResult
    private static func deleteKeychainItem(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
