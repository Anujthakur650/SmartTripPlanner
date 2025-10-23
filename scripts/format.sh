#!/usr/bin/env bash

set -euo pipefail

PACKAGE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Modules"

targets=(Core Services UIComponents Features AppShell)

for target in "${targets[@]}"; do
  swift package --package-path "$PACKAGE_PATH" \
    plugin --allow-writing-to-package-directory \
    --target "$target" \
    --plugin SwiftFormatPlugin
done
