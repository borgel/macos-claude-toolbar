import SwiftUI

struct UsagePopoverView: View {
    @EnvironmentObject var apiClient: UsageAPIClient
    @EnvironmentObject var authManager: AuthManager
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            if showSettings {
                SettingsView()
                    .environmentObject(authManager)
            } else {
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Error banner
                        if let error = apiClient.usageData.error {
                            errorBanner(error)
                        }

                        // Sections
                        if let session = apiClient.usageData.session {
                            SessionUsageView(session: session)
                        }

                        if let weekly = apiClient.usageData.weeklyLimits {
                            Divider()
                            WeeklyLimitsView(limits: weekly)
                        }

                        if let extra = apiClient.usageData.extraUsage {
                            Divider()
                            ExtraUsageView(extra: extra)
                        }

                        if !apiClient.usageData.hasAnyData && apiClient.usageData.error == nil {
                            noDataView
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }

            Divider()

            // Footer
            footer
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
        .frame(width: 340, height: 420)
        .task {
            await apiClient.fetchUsage()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Claude Usage")
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            if apiClient.isFetching {
                ProgressView()
                    .controlSize(.small)
            }

            Button(action: {
                Task { await apiClient.fetchUsage() }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(apiClient.isFetching)

            if let lastUpdated = apiClient.usageData.lastUpdated {
                Text(lastUpdated, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(showSettings ? "Back" : "Settings") {
                showSettings.toggle()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ error: UsageError) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(error.errorDescription ?? "Unknown error")
                .font(.caption)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - No Data

    private var noDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No usage data available")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Check your authentication in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
