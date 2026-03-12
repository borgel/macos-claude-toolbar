import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var manualToken = ""
    @State private var showToken = false
    @AppStorage("redThresholdPercent") private var redThreshold: Double = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            // Auth source
            Group {
                switch authManager.state {
                case .authenticated(_, let source):
                    Label("Authenticated via \(source.rawValue)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .notAuthenticated:
                    Label("Not authenticated", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                case .expired:
                    Label("Token expired", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                case .error(let msg):
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
            .font(.subheadline)

            Divider()

            // Red threshold setting
            VStack(alignment: .leading, spacing: 4) {
                Text("Alert Threshold")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Slider(value: $redThreshold, in: 50...100, step: 5)
                    Text("\(Int(redThreshold))%")
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(width: 40, alignment: .trailing)
                }

                Text("Icon turns red at this usage level")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Manual token entry
            Text("Manual Token")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                if showToken {
                    TextField("Paste OAuth token...", text: $manualToken)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                } else {
                    SecureField("Paste OAuth token...", text: $manualToken)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }

                Button(action: { showToken.toggle() }) {
                    Image(systemName: showToken ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }

            HStack {
                Button("Save Token") {
                    authManager.setManualToken(manualToken)
                    manualToken = ""
                }
                .disabled(manualToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Clear") {
                    authManager.clearManualToken()
                    manualToken = ""
                }
                .foregroundColor(.red)

                Spacer()

                Button("Re-check Keychain") {
                    authManager.resolveCredentials()
                }
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 340)
    }
}
