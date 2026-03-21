# Changelog

## 0.2.6 (2026-03-20)

### Fixed
- Fix process hang after biometric commands by adding explicit `exit(0)` to drain lingering LAContext dispatch queues

## 0.2.5 (2026-03-20)

### Fixed
- Fix OSStatus -34018 on `set --biometric` by replacing keychain-level biometric ACL (requires Apple Developer entitlements) with explicit Touch ID authentication via LAContext

## 0.2.4 (2026-03-20)

### Fixed
- Prompt Touch ID biometric confirmation on `set --biometric` (previously only configured ACL for reads without prompting on write)

## 0.2.3 (2026-03-20)

### Fixed
- Fix SIGKILL (exit code 137) on ad-hoc signed binaries by removing unresolvable `keychain-access-groups` entitlement with `$(AppIdentifierPrefix)` variable

## 0.2.2 (2026-03-20)

### Fixed
- Include entitlements files in published npm package, fixing `postinstall` codesign failure for consumers

## 0.2.0 (2026-03-19)

### Breaking
- Package renamed from `@flnx/keychain` to `@mishrab/keychain`

### Fixed
- Fix `OSStatus -34018` error by codesigning binary with keychain-access-groups entitlement
- Add actionable error message when keychain entitlements are missing

### Changed
- Exclude Swift build artifacts from npm tarball (33.8 MB → 51.6 kB)
- Add `.npmrc` support for auth token storage (gitignored)
- Build script now fails with clear guidance if codesigning fails

## 0.1.0 (2026-03-08)

Initial release.

- Swift keychain-helper binary with Keychain + Touch ID biometric support
- TypeScript layer with types, errors, and keychain bridge
- CLI with `set`, `get`, `delete`, `has` commands
- Universal binary build (arm64 + x86_64)
- Unit tests for errors, keychain module, and CLI arg parsing
