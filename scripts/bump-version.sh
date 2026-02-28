#!/usr/bin/env bash
set -euo pipefail
# Delegates to ic publish for version management
if command -v ic &>/dev/null; then
    ic publish "$@"
else
    echo "ic not found — install intercore CLI" >&2
    exit 1
fi
