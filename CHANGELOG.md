# Changelog

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
