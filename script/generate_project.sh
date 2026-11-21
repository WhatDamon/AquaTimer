#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen is required to regenerate the project: brew install xcodegen" >&2
    exit 1
fi
xcodegen generate --spec "$ROOT_DIR/project.yml" --project "$ROOT_DIR"

