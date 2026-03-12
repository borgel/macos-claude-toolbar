import Cocoa
import Combine
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    private let authManager = AuthManager()
    private var apiClient: UsageAPIClient!
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Refresh intervals
    private let normalInterval: TimeInterval = 5 * 60    // 5 minutes
    private let rateLimitedInterval: TimeInterval = 15 * 60  // 15 minutes

    func applicationDidFinishLaunching(_ notification: Notification) {
        apiClient = UsageAPIClient(authManager: authManager)

        // Status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "—%"
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Popover with SwiftUI content
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: UsagePopoverView()
                .environmentObject(apiClient!)
                .environmentObject(authManager)
        )

        // Observe usage data changes to update status bar text
        apiClient.$usageData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.updateStatusBarText(data)
            }
            .store(in: &cancellables)

        // Resolve credentials and do initial fetch
        authManager.resolveCredentials()
        Task {
            await apiClient.fetchUsage()
        }

        // Start refresh timer
        startRefreshTimer(interval: normalInterval)
    }

    // MARK: - Status Bar

    private func updateStatusBarText(_ data: UsageDisplayData) {
        guard let button = statusItem.button else { return }

        if let session = data.session {
            button.title = "\(Int(session.percentUsed))%"
        } else {
            button.title = "—%"
        }
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)

            // Refresh on open
            Task { await apiClient.fetchUsage() }
        }
    }

    // MARK: - Refresh Timer

    private func startRefreshTimer(interval: TimeInterval) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.apiClient.fetchUsage()

                // Switch to rate-limited interval if needed
                if case .rateLimited = self.apiClient.usageData.error {
                    self.startRefreshTimer(interval: self.rateLimitedInterval)
                } else {
                    self.startRefreshTimer(interval: self.normalInterval)
                }
            }
        }
    }
}
