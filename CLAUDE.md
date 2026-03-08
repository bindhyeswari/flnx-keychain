# CLAUDE.md — keychain-touch-id

## Project Overview
macOS Keychain access with Touch ID biometric confirmation. Single npm package combining TypeScript (library + CLI) with a native Swift binary. Zero runtime dependencies.

## Tech Stack
- **Runtime**: Bun (primary), Node 18+ compatible
- **Languages**: TypeScript + Swift 5.9+
- **Platform**: macOS 13+ only
- **Apple Frameworks**: Security (Keychain Services), LocalAuthentication (Touch ID)

## Project Structure
```
src/              # TypeScript source
  index.ts        # Library entry point (exports public API)
  cli.ts          # CLI entry point (shebang: #!/usr/bin/env bun)
  keychain.ts     # Core module — Swift binary bridge via subprocess
  errors.ts       # Custom error hierarchy
  types.ts        # Shared type definitions
native/keychain-helper/
  Package.swift   # Swift package manifest
  Sources/main.swift  # Single-file Swift CLI (~100-150 lines)
scripts/
  build-swift.sh  # Compile universal binary (arm64 + x86_64)
  prepack.sh      # Pre-publish checks
bin/              # Compiled Swift binary (gitignored, built on install)
dist/             # Compiled TS output (gitignored, built on publish)
```

## Commands
```bash
bun install                # Install dependencies
bun run build:swift        # Build Swift universal binary
bun run build:ts           # Build TypeScript
bun run build              # Build everything
bun test                   # Run tests (Bun test runner)
bun run typecheck          # Type check
bun run src/cli.ts         # Run CLI in dev mode
```

## Architecture Decisions
- **Subprocess bridge, not FFI** — Swift binary invoked as child process with JSON I/O. Avoids Touch ID runloop issues within FFI.
- **Secrets via stdin** — `set` command reads secrets from stdin, never argv (prevents shell history leakage).
- **Universal binary** — arm64 + x86_64 combined via `lipo`, compiled on `postinstall`.
- **Zero deps** — No npm runtime dependencies. System frameworks only for Swift.
- **Exit codes** — 0=success, 1=not found, 2=auth failed, 3=platform error.

## Key APIs
```typescript
setSecret(secret: string, options: SetOptions): Promise<void>
getSecret(options: GetOptions): Promise<string>
deleteSecret(options: KeychainItemIdentifier): Promise<void>
hasSecret(options: KeychainItemIdentifier): Promise<boolean>
```

## Task Tracking
- See **TASKS.md** for current and completed tasks.
- **On commit**: After completing a commit (when requested), ask the user what the next tasks should be. Update TASKS.md accordingly — mark completed tasks as done, remove stale tasks, and add new ones.

## Conventions
- Use `bun` for all package management and script execution
- Refer to ARCHITECTURE.md for the full technical specification
- Keep Swift binary stateless — all business logic in TypeScript
- Strict TypeScript (`strict: true`, ES2022 target, `moduleResolution: bundler`)
