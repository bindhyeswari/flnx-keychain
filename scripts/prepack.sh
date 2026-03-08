#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check Swift source exists
if [ ! -f "$PROJECT_ROOT/native/keychain-helper/Sources/main.swift" ]; then
  echo "Error: Swift source not found at native/keychain-helper/Sources/main.swift" >&2
  exit 1
fi

# Check TypeScript build output exists
if [ ! -d "$PROJECT_ROOT/dist" ]; then
  echo "Error: dist/ not found. Run 'bun run build' first." >&2
  exit 1
fi

if [ ! -f "$PROJECT_ROOT/dist/index.js" ]; then
  echo "Error: dist/index.js not found. Run 'bun run build:ts' first." >&2
  exit 1
fi

echo "Pre-pack checks passed"
