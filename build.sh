#!/bin/bash
set -euo pipefail

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building ClaudeUsageBar (Release)..."
xcodebuild \
    -project ClaudeUsageBar.xcodeproj \
    -scheme ClaudeUsageBar \
    -configuration Release \
    -derivedDataPath build \
    build

APP_PATH="build/Build/Products/Release/ClaudeUsageBar.app"
echo "==> Build complete: $APP_PATH"
