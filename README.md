# Claude Usage Bar

A macOS menu bar app that displays your Claude AI usage statistics. Shows your current session utilization percentage directly in the menu bar, with a detailed popover dashboard for weekly limits, per-model breakdowns, and billing info.

Requires macOS 14.0 (Sonoma) or later.

## Features

- **Menu bar indicator** — current 5-hour session usage as a percentage, color-coded blue/orange/red
- **Popover dashboard** — session usage, weekly limits (all models + Sonnet-only), extra usage/billing details
- **Auto-refresh** — polls every 5 minutes (backs off to 15 minutes if rate-limited)
- **Configurable alert threshold** — set when the bar turns red (default 90%)

## Authentication

The app needs an Anthropic API token to fetch usage data. It checks two sources, in order:

### 1. Claude Code OAuth token (automatic)

If you have [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated, the app reads its OAuth token directly from the macOS Keychain (service `Claude Code-credentials`, account = your macOS username). The token is checked for expiration before use. **This is the recommended approach** — no manual setup needed.

### 2. Manual token (fallback)

If no valid Claude Code token is found, the app falls back to a manually entered token. Open the Settings tab in the popover and paste your token. It is stored in the macOS Keychain under service `com.borgel.ClaudeUsageBar`.

### Auth state

The app tracks authentication as a state machine:
- **Authenticated** — a valid token was resolved (displays which source is in use)
- **Expired** — the Claude Code token has expired; falls through to manual token
- **Not Authenticated** — no token found from either source
- **Error** — something went wrong reading credentials

## API

The app calls `GET https://api.anthropic.com/api/oauth/usage` with the resolved bearer token. The response includes 5-hour session utilization, 7-day limits per model family, and extra-usage billing data.

## Building

### Prerequisites

- Xcode 15+ (with command-line tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.35+

Install XcodeGen if you don't have it:

```sh
brew install xcodegen
```

### Build

A convenience script is provided:

```sh
./build.sh
```

This regenerates the Xcode project from `project.yml` and builds a Release binary. The compiled `.app` bundle lands in `build/Build/Products/Release/`.

To open in Xcode instead:

```sh
xcodegen generate
open ClaudeUsageBar.xcodeproj
```

### Pre-built binary

Download the latest build from [GitHub Actions](https://github.com/borgel/macos-claude-toolbar/actions/workflows/build.yml) — click the most recent successful run and grab the **ClaudeUsageBar** artifact.

### Install

Copy `ClaudeUsageBar.app` to `/Applications` (or anywhere you like) and launch it. The app runs as a menu bar item with no Dock icon.
