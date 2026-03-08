# TASKS.md — keychain-touch-id

## Current Tasks

_(none — all initial tasks complete)_

## Completed Tasks

- [x] **Scaffold the project** — Created `package.json`, `tsconfig.json`, `.gitignore`
- [x] **Build the Swift binary** — Created `native/keychain-helper/` with `Package.swift` and `Sources/main.swift`
- [x] **Implement TypeScript layer** — Types (`types.ts`), errors (`errors.ts`), keychain bridge (`keychain.ts`), library entry point (`index.ts`)
- [x] **Build the CLI** — Implemented `src/cli.ts` with `set`, `get`, `delete`, `has` commands
- [x] **Add build scripts** — `scripts/build-swift.sh`, `scripts/prepack.sh`, wired up `package.json` scripts
- [x] **Write tests** — Unit tests for error hierarchy, keychain module platform checks, CLI argument parsing
