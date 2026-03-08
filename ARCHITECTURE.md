# Architecture Document: `keychain-touch-id`

> A single npm package that provides macOS Keychain access with Touch ID biometric confirmation. Built with Bun + TypeScript, backed by a small native Swift binary.

---

## 1. Overview

This package allows CLI tools and Node/Bun applications to securely store, retrieve, and delete secrets (tokens, API keys, passwords) in the macOS Keychain, optionally requiring Touch ID biometric authentication before a secret is released.

It ships as a single npm package with:
- A **TypeScript library** (programmatic API)
- A **CLI tool** (interactive terminal use)
- A **compiled Swift helper binary** (native macOS Keychain + Touch ID bridge)

---

## 2. Design Principles

- **Single package**: Everything installs via `npm install keychain-touch-id`. No external dependencies, no separate native module installs.
- **Subprocess, not FFI**: The Swift binary is invoked as a subprocess, not via `bun:ffi` or `node-ffi`. This is intentional — Touch ID requires a runloop, which is awkward inside FFI. Subprocess keeps it clean and debuggable.
- **Swift for native, not Rust or C**: The macOS Security framework and LocalAuthentication are Objective-C/Swift APIs. Swift gives first-class, zero-friction access. Rust would require the `objc` crate and manual ObjC message sends.
- **macOS only**: This package only targets macOS (Darwin). The `os` field in package.json enforces this. Cross-platform secret storage is out of scope.
- **Minimal surface area**: The Swift binary does one thing (Keychain CRUD + Touch ID). All business logic, argument parsing, and UX lives in TypeScript.

---

## 3. Project Structure

```
keychain-touch-id/
├── package.json
├── tsconfig.json
├── ARCHITECTURE.md              # This file
├── README.md
│
├── src/                         # TypeScript source
│   ├── index.ts                 # Library entry — exports the programmatic API
│   ├── cli.ts                   # CLI entry — argument parsing, interactive prompts
│   ├── keychain.ts              # Core module — spawns Swift binary, handles I/O
│   ├── errors.ts                # Custom error classes
│   └── types.ts                 # Shared type definitions
│
├── native/
│   └── keychain-helper/         # Swift package
│       ├── Package.swift        # Swift package manifest (swift-tools-version 5.9+)
│       └── Sources/
│           └── main.swift       # Single-file Swift CLI (~100-150 lines)
│
├── scripts/
│   ├── build-swift.sh           # Compiles the Swift binary (universal: arm64 + x86_64)
│   └── prepack.sh               # Pre-publish checks (ensures binary exists, runs tests)
│
├── bin/
│   └── keychain-helper          # Compiled universal binary (gitignored, built on install)
│
└── dist/                        # Compiled TS output (gitignored, built on publish)
    ├── index.js
    ├── index.d.ts
    ├── cli.js
    └── ...
```

---

## 4. Component Details

### 4.1 Swift Binary (`native/keychain-helper/`)

**Purpose**: Thin native bridge to macOS Keychain + Touch ID. Does no business logic.

**Package.swift Configuration**:
- Swift tools version: 5.9+
- Single executable target named `keychain-helper`
- No external dependencies — uses only Apple system frameworks

**Linked Frameworks**:
- `Security` — Keychain Services API (`SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`)
- `LocalAuthentication` — Touch ID / biometric context (`LAContext`)

**CLI Interface** (invoked as subprocess):

```
keychain-helper <command> --service <string> --account <string> [options]
```

**Commands**:

| Command  | Description                        | Stdin          | Stdout               |
|----------|------------------------------------|----------------|-----------------------|
| `set`    | Store a secret in the Keychain     | secret value   | `{"ok": true}`        |
| `get`    | Retrieve a secret (triggers biometric if configured) | —  | `{"ok": true, "value": "..."}` |
| `delete` | Remove a secret from the Keychain  | —              | `{"ok": true}`        |
| `has`    | Check if a secret exists           | —              | `{"ok": true, "exists": true}` |

**Flags**:

| Flag                  | Type    | Default | Description                                           |
|-----------------------|---------|---------|-------------------------------------------------------|
| `--service`           | string  | required| Keychain service identifier (e.g., `com.myapp.token`) |
| `--account`           | string  | required| Keychain account label (e.g., `default`, `staging`)   |
| `--biometric`         | bool    | false   | Require Touch ID to access this item                  |
| `--biometric-reason`  | string  | `"authenticate to access secret"` | The message shown in the Touch ID dialog |

**Output Protocol**:
- All output is **JSON on stdout**, one object per invocation.
- On success: `{"ok": true, ...}` with command-specific fields.
- On error: `{"ok": false, "error": "<code>", "message": "<human-readable>"}`.
- Exit code 0 on success, non-zero on failure.
- The binary must never print anything to stdout other than the JSON response. Diagnostic/debug info goes to stderr only.

**Error Codes** (returned in the `error` field):

| Code                  | Meaning                                      |
|-----------------------|----------------------------------------------|
| `item_not_found`      | No keychain item matches the service+account |
| `duplicate_item`      | Item already exists (on `set` without update)|
| `auth_failed`         | Touch ID / biometric auth was denied/failed  |
| `auth_cancelled`      | User cancelled the biometric prompt          |
| `not_available`       | Biometrics not available on this device      |
| `keychain_error`      | Generic Keychain error (include OSStatus)    |

**SecAccessControl Configuration** (when `--biometric` is set):
- Use `SecAccessControlCreateWithFlags` with:
  - `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — secret only accessible when device is unlocked, never synced to other devices or backups.
  - `.biometryCurrentSet` — invalidates if fingerprints/face change (more secure than `.biometryAny`).

**Secret Input for `set` command**:
- The secret value is read from **stdin**, not from a CLI argument. This avoids the secret appearing in `ps` output or shell history.
- The binary reads stdin to EOF, trims trailing whitespace, and stores the result.

**Implementation Notes**:
- Use `DispatchSemaphore` to block the main thread while the async Touch ID callback completes (since this is a CLI, not a GUI app).
- For the `set` command: attempt `SecItemAdd` first. If it returns `errSecDuplicateItem`, fall back to `SecItemUpdate` (upsert behavior).
- Keep the binary stateless — no config files, no caching, no side effects beyond Keychain writes.

---

### 4.2 Swift Build Script (`scripts/build-swift.sh`)

**Purpose**: Compiles the Swift binary as a universal (fat) binary supporting both arm64 and x86_64.

**Behavior**:
1. Check if running on macOS (`uname -s`). If not, print a warning and exit 0 (don't fail the install on CI Linux runners).
2. Check if `swift` is available. If not, print an error with install instructions (Xcode Command Line Tools).
3. `cd` into `native/keychain-helper/`.
4. Build for arm64: `swift build -c release --arch arm64`
5. Build for x86_64: `swift build -c release --arch x86_64`
6. Combine with `lipo -create -output ../../bin/keychain-helper <arm64-binary> <x86_64-binary>`.
7. `chmod +x ../../bin/keychain-helper`.
8. Verify with `file ../../bin/keychain-helper` (should show "Mach-O universal binary").

**Edge case**: If only one architecture is available (e.g., CI machine is arm64-only and Rosetta isn't installed), fall back to single-arch build and warn.

---

### 4.3 TypeScript: Types (`src/types.ts`)

```typescript
export interface KeychainItemIdentifier {
  service: string;       // e.g., "com.myapp.api-token"
  account?: string;      // defaults to "default"
}

export interface SetOptions extends KeychainItemIdentifier {
  biometric?: boolean;              // default: false
  biometricReason?: string;         // Touch ID dialog message
}

export interface GetOptions extends KeychainItemIdentifier {
  biometricReason?: string;         // override the stored reason
}

export interface KeychainResult {
  ok: boolean;
  value?: string;
  exists?: boolean;
  error?: string;
  message?: string;
}
```

---

### 4.4 TypeScript: Errors (`src/errors.ts`)

Define custom error classes that map to the Swift binary's error codes:

| Class                     | Extends        | When Thrown                                |
|---------------------------|----------------|--------------------------------------------|
| `KeychainError`           | `Error`        | Base class for all keychain errors         |
| `ItemNotFoundError`       | `KeychainError`| `get` or `delete` with no matching item    |
| `AuthFailedError`         | `KeychainError`| Touch ID authentication failed             |
| `AuthCancelledError`      | `KeychainError`| User pressed Cancel on Touch ID prompt     |
| `BiometricNotAvailable`   | `KeychainError`| No Touch ID hardware or not enrolled       |
| `PlatformError`           | `KeychainError`| Not running on macOS                       |

Each error class should include the raw error code and message from the Swift binary.

---

### 4.5 TypeScript: Core Module (`src/keychain.ts`)

**Purpose**: Spawns the Swift binary and translates results into the TypeScript API.

**Binary Resolution**:
1. Resolve the path to `bin/keychain-helper` relative to the package root (use `import.meta.dir` or `import.meta.url`).
2. On first call, verify the binary exists and is executable. If not, throw `PlatformError` with a message suggesting `npm rebuild` or manual build.

**Spawn Mechanism**:
- Use `Bun.spawn()` (preferred) or `child_process.execFile` for Node compat.
- For the `set` command, pipe the secret into stdin.
- Capture stdout and stderr separately.
- Set a timeout (default 30 seconds — Touch ID can take a while if the user hesitates).

**Response Parsing**:
- Parse stdout as JSON.
- If `ok: true`, return the relevant data.
- If `ok: false`, throw the appropriate typed error from `errors.ts`.
- If the process exits non-zero but stdout is empty (crash), throw a generic `KeychainError` with stderr contents.

**Exported Functions**:

```typescript
export async function setSecret(secret: string, options: SetOptions): Promise<void>
export async function getSecret(options: GetOptions): Promise<string>
export async function deleteSecret(options: KeychainItemIdentifier): Promise<void>
export async function hasSecret(options: KeychainItemIdentifier): Promise<boolean>
```

---

### 4.6 TypeScript: Library Entry (`src/index.ts`)

Re-exports everything a consumer needs:

```typescript
export { setSecret, getSecret, deleteSecret, hasSecret } from "./keychain.ts";
export { KeychainError, ItemNotFoundError, AuthFailedError, AuthCancelledError, BiometricNotAvailable, PlatformError } from "./errors.ts";
export type { KeychainItemIdentifier, SetOptions, GetOptions, KeychainResult } from "./types.ts";
```

---

### 4.7 TypeScript: CLI Entry (`src/cli.ts`)

**Purpose**: Provides a `keychain-touch-id` command for interactive terminal use and scripting.

**Shebang**: `#!/usr/bin/env bun`

**Commands**:

```
keychain-touch-id set <service> [--account <name>] [--biometric] [--reason <text>]
keychain-touch-id get <service> [--account <name>] [--reason <text>]
keychain-touch-id delete <service> [--account <name>]
keychain-touch-id has <service> [--account <name>]
```

**Argument Parsing**:
- Use `process.argv` manually or `util.parseArgs` (built into Node 18+ / Bun). No external CLI framework needed for this surface area.

**Behavior by Command**:

- **`set`**: If stdin is a TTY, prompt interactively for the secret (hide input like a password prompt). If stdin is piped, read from stdin. This allows both `keychain-touch-id set com.myapp.token` (interactive) and `echo "secret" | keychain-touch-id set com.myapp.token` (scripted).
- **`get`**: Print the secret to stdout (for piping). Print nothing else to stdout.
- **`delete`**: Print a confirmation message to stderr.
- **`has`**: Exit code 0 if exists, exit code 1 if not. Print `true`/`false` to stdout.

**Error Handling**:
- Catch typed errors and print user-friendly messages to stderr.
- Set appropriate exit codes (0 = success, 1 = item not found / does not exist, 2 = auth failed/cancelled, 3 = platform error).

---

## 5. Package Lifecycle

### 5.1 Install Flow

When a user runs `npm install keychain-touch-id`:

1. npm downloads the package.
2. `postinstall` script runs `scripts/build-swift.sh`.
3. Swift source is compiled into a universal binary at `bin/keychain-helper`.
4. Package is ready to use.

**Requirements on the user's machine**:
- macOS (any supported version with Swift 5.9+ — macOS 13+)
- Xcode Command Line Tools installed (`xcode-select --install`)

### 5.2 Publish Flow

When the maintainer runs `npm publish`:

1. `prepublishOnly` runs the full `build` script.
2. The `files` field in package.json controls what's included in the tarball: `dist/`, `native/` (Swift source), `scripts/`, `bin/` (if pre-built).
3. The Swift source is always included so it can be compiled on install.

### 5.3 Pre-built Binary Strategy (Future Enhancement)

For faster installs, you could optionally pre-build and include the universal binary in the npm tarball. The `postinstall` script would then check if `bin/keychain-helper` already exists and skip the build. This avoids requiring Xcode CLI tools on the user's machine but increases package size (~1MB).

An even more advanced approach: publish platform-specific optional dependencies (like `@keychain-touch-id/darwin-arm64`) and use npm's `optionalDependencies` + `os`/`cpu` fields to auto-select. This is the pattern `esbuild`, `swc`, and `turbo` use. This is out of scope for v0.1 but worth noting for future scaling.

---

## 6. Security Considerations

| Concern                        | Mitigation                                                                 |
|--------------------------------|---------------------------------------------------------------------------|
| Secret in process arguments    | `set` reads from stdin, never from argv. Secrets never appear in `ps`.    |
| Secret in shell history        | CLI prompts interactively for secrets when stdin is a TTY.                |
| Keychain item accessibility    | Uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — no sync, no backup. |
| Biometric bypass               | `.biometryCurrentSet` invalidates if biometric enrollment changes.        |
| Binary tampering               | Built from source on install. Future: code-sign the binary.              |
| Stdout leakage                 | `get` outputs only the secret, nothing else. All diagnostics go to stderr.|

---

## 7. Usage Examples

### 7.1 Programmatic (Library)

```typescript
import { setSecret, getSecret, hasSecret, AuthCancelledError } from "keychain-touch-id";

// Store a token with Touch ID protection
await setSecret("ghp_abc123...", {
  service: "com.myapp.github-token",
  biometric: true,
  biometricReason: "Access your GitHub token",
});

// Retrieve it (triggers Touch ID)
try {
  const token = await getSecret({
    service: "com.myapp.github-token",
  });
  console.log("Authenticated, token retrieved.");
} catch (err) {
  if (err instanceof AuthCancelledError) {
    console.log("User cancelled authentication.");
  }
}
```

### 7.2 CLI

```bash
# Store interactively (prompts for secret)
keychain-touch-id set com.myapp.token --biometric --reason "Unlock API key"

# Store from pipe
echo "ghp_abc123" | keychain-touch-id set com.myapp.token --biometric

# Retrieve (triggers Touch ID, prints to stdout)
TOKEN=$(keychain-touch-id get com.myapp.token)

# Check existence
if keychain-touch-id has com.myapp.token; then
  echo "Token is stored"
fi

# Delete
keychain-touch-id delete com.myapp.token
```

### 7.3 Session Bootstrap Pattern

The primary use case — loading tokens at CLI tool startup:

```typescript
import { getSecret, hasSecret, setSecret, ItemNotFoundError } from "keychain-touch-id";

const SERVICE = "com.mycompany.cli";

async function ensureToken(): Promise<string> {
  // Check if we have a stored token
  if (await hasSecret({ service: SERVICE })) {
    // Retrieve with Touch ID
    return await getSecret({ service: SERVICE });
  }

  // First run — prompt user for token and store it
  const token = prompt("Enter your API token: ");
  await setSecret(token, {
    service: SERVICE,
    biometric: true,
    biometricReason: "Authenticate to load your API token",
  });

  return token;
}

// At app startup
const token = await ensureToken();
// Use token for API calls...
```

---

## 8. tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "declaration": true,
    "outDir": "dist",
    "rootDir": "src",
    "types": ["bun-types"],
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "native"]
}
```

---

## 9. .gitignore

```
node_modules/
dist/
bin/keychain-helper
.build/
native/keychain-helper/.build/
```

---

## 10. Testing Strategy

### Unit Tests (TypeScript)
- Mock the Swift binary subprocess to test `keychain.ts` response parsing, error mapping, and edge cases (empty stdout, timeout, crash).
- Test CLI argument parsing with various input combinations.
- Use Bun's built-in test runner (`bun test`).

### Integration Tests (requires macOS)
- Actually call the Swift binary against the real Keychain.
- Use a unique service prefix (e.g., `com.keychain-touch-id.test.*`) to avoid collisions.
- Clean up test items in an `afterAll` hook.
- Biometric tests must be skipped in CI (no Touch ID available). Gate with an environment variable: `KEYCHAIN_TEST_BIOMETRIC=1`.

### Swift Tests
- Test the binary directly via shell invocation.
- Verify JSON output format for each command and error case.
- Verify stdin reading for `set`.

---

## 11. Build & Run Commands Reference

| Task                    | Command                          |
|-------------------------|----------------------------------|
| Install dependencies    | `bun install`                    |
| Build Swift binary      | `bun run build:swift`            |
| Build TypeScript        | `bun run build:ts`               |
| Build everything        | `bun run build`                  |
| Run CLI in dev          | `bun run src/cli.ts`             |
| Run tests               | `bun test`                       |
| Type check              | `bun run typecheck`              |
| Publish                 | `npm publish`                    |

---

## 12. Dependencies

### Runtime Dependencies
**None.** This package has zero npm runtime dependencies.

### Dev Dependencies
- `typescript` — type checking (not used for compilation; Bun handles that)
- `@types/bun` — Bun type definitions

### System Requirements
- macOS 13+ (Ventura or later)
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+ (included with Xcode CLI tools)
- Bun 1.0+ (for development) or Node 18+ (for consumers)