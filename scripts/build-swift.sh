#!/bin/bash
set -euo pipefail

# Only build on macOS
if [ "$(uname -s)" != "Darwin" ]; then
  echo "⚠ Skipping Swift build — not running on macOS"
  exit 0
fi

# Check for Swift
if ! command -v swift &>/dev/null; then
  echo "Error: Swift is not installed. Run: xcode-select --install" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SWIFT_DIR="$PROJECT_ROOT/native/keychain-helper"
BIN_DIR="$PROJECT_ROOT/bin"
ENTITLEMENTS="$SWIFT_DIR/keychain-helper.entitlements"

mkdir -p "$BIN_DIR"
cd "$SWIFT_DIR"

echo "Building keychain-helper..."

# Try universal binary first (arm64 + x86_64)
ARM64_OK=0
X86_OK=0

swift build -c release --arch arm64 2>/dev/null && ARM64_OK=1 || true
swift build -c release --arch x86_64 2>/dev/null && X86_OK=1 || true

if [ "$ARM64_OK" -eq 1 ] && [ "$X86_OK" -eq 1 ]; then
  ARM64_BIN=$(swift build -c release --arch arm64 --show-bin-path)/keychain-helper
  X86_BIN=$(swift build -c release --arch x86_64 --show-bin-path)/keychain-helper
  lipo -create -output "$BIN_DIR/keychain-helper" "$ARM64_BIN" "$X86_BIN"
  echo "Built universal binary (arm64 + x86_64)"
elif [ "$ARM64_OK" -eq 1 ]; then
  ARM64_BIN=$(swift build -c release --arch arm64 --show-bin-path)/keychain-helper
  cp "$ARM64_BIN" "$BIN_DIR/keychain-helper"
  echo "Warning: Built arm64 only (x86_64 build failed)" >&2
elif [ "$X86_OK" -eq 1 ]; then
  X86_BIN=$(swift build -c release --arch x86_64 --show-bin-path)/keychain-helper
  cp "$X86_BIN" "$BIN_DIR/keychain-helper"
  echo "Warning: Built x86_64 only (arm64 build failed)" >&2
else
  echo "Error: Swift build failed for all architectures" >&2
  exit 1
fi

chmod +x "$BIN_DIR/keychain-helper"

# Sign with entitlements for Keychain access
# Without this, Keychain operations fail with OSStatus -34018
echo "Signing with keychain entitlements..."
if ! codesign --force --sign - --entitlements "$ENTITLEMENTS" "$BIN_DIR/keychain-helper"; then
  echo "Error: codesign failed. Keychain operations will not work without entitlements (OSStatus -34018)." >&2
  echo "Ensure Xcode command line tools are installed: xcode-select --install" >&2
  exit 1
fi

echo "keychain-helper built successfully"
