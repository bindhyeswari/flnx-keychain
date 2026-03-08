# TASKS.md — keychain-touch-id

## Current Tasks

### Publishing Prep
- [ ] **Verify on macOS** — Build and run full test suite on macOS to confirm Swift compilation and keychain integration
- [ ] **Check npm name** — Confirm `keychain-touch-id` is available on npm; scope if taken
- [ ] **Dry run** — Run `npm pack --dry-run` to verify tarball contents (dist/, native/, scripts/, bin/)
- [ ] **npm login & publish** — Authenticate and run `npm publish`
- [ ] **Post-publish smoke test** — Install from npm in a fresh project on macOS, verify set/get/delete/has

## Completed Tasks

- [x] **Scaffold the project** — Created `package.json`, `tsconfig.json`, `.gitignore`
- [x] **Build the Swift binary** — Created `native/keychain-helper/` with `Package.swift` and `Sources/main.swift`
- [x] **Implement TypeScript layer** — Types (`types.ts`), errors (`errors.ts`), keychain bridge (`keychain.ts`), library entry point (`index.ts`)
- [x] **Build the CLI** — Implemented `src/cli.ts` with `set`, `get`, `delete`, `has` commands
- [x] **Add build scripts** — `scripts/build-swift.sh`, `scripts/prepack.sh`, wired up `package.json` scripts
- [x] **Write tests** — Unit tests for error hierarchy, keychain module platform checks, CLI argument parsing
- [x] **Add README** — Usage docs for API, CLI, error handling, and security notes
- [x] **Add LICENSE** — MIT license file
