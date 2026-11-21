#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
xcodebuild \
    -project "$ROOT_DIR/AquaTimer.xcodeproj" \
    -scheme AquaTimer \
    -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$ROOT_DIR/.build/DerivedData" \
    -parallel-testing-enabled NO \
    -quiet \
    test
