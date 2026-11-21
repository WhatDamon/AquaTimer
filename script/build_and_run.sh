#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
    run|--debug|--logs|--telemetry|--verify) ;;
    *)
        echo "usage: $0 [--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AquaTimer"
BUNDLE_ID="dev.aquatimer.AquaTimer"
DERIVED_DATA="$ROOT_DIR/.build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [[ ! -d "$ROOT_DIR/AquaTimer.xcodeproj" ]]; then
    "$ROOT_DIR/script/generate_project.sh"
fi

xcodebuild \
    -project "$ROOT_DIR/AquaTimer.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    build

case "$MODE" in
    run)
        /usr/bin/open -n "$APP_BUNDLE"
        ;;
    --debug)
        xcrun lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
        ;;
    --logs)
        /usr/bin/open -n "$APP_BUNDLE"
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry)
        /usr/bin/open -n "$APP_BUNDLE"
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify)
        /usr/bin/open -n "$APP_BUNDLE"
        for attempt in {1..20}; do
            if pgrep -x "$APP_NAME" >/dev/null; then
                echo "$APP_NAME launched successfully."
                exit 0
            fi
            sleep 0.25
        done
        echo "$APP_NAME did not start." >&2
        exit 1
        ;;
esac
