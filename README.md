# @flnx/keychain

macOS Keychain access with Touch ID biometric confirmation. Store, retrieve, and manage secrets with optional biometric authentication.

- **Touch ID integration** — Require biometric confirmation before releasing secrets
- **Zero runtime dependencies** — Uses only macOS system frameworks
- **TypeScript + Swift** — Type-safe API backed by a native Keychain Services bridge
- **CLI included** — Use programmatically or from the terminal

## Requirements

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools (`xcode-select --install`)
- Node 18+ or Bun 1.0+

## Install

```bash
npm install @flnx/keychain
```

The Swift helper binary compiles from source during `postinstall`. This requires Xcode Command Line Tools.

## API

```typescript
import { setSecret, getSecret, hasSecret, deleteSecret } from "@flnx/keychain";

// Store a secret with Touch ID protection
await setSecret("ghp_abc123...", {
  service: "com.myapp.github-token",
  biometric: true,
  biometricReason: "Access your GitHub token",
});

// Retrieve it (triggers Touch ID if biometric was set)
const token = await getSecret({
  service: "com.myapp.github-token",
});

// Check existence
const exists = await hasSecret({ service: "com.myapp.github-token" });

// Delete
await deleteSecret({ service: "com.myapp.github-token" });
```

### Options

**`setSecret(secret, options)`**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `service` | `string` | required | Keychain service identifier |
| `account` | `string` | `"default"` | Keychain account label |
| `biometric` | `boolean` | `false` | Require Touch ID |
| `biometricReason` | `string` | `"authenticate to access secret"` | Touch ID dialog message |

**`getSecret(options)`** — Returns the secret string. Options: `service`, `account`, `biometricReason`.

**`hasSecret(options)`** — Returns `boolean`. Options: `service`, `account`.

**`deleteSecret(options)`** — Returns `void`. Options: `service`, `account`.

### Error Handling

```typescript
import { AuthCancelledError, ItemNotFoundError } from "@flnx/keychain";

try {
  const secret = await getSecret({ service: "com.myapp.token" });
} catch (err) {
  if (err instanceof AuthCancelledError) {
    // User cancelled Touch ID prompt
  } else if (err instanceof ItemNotFoundError) {
    // No secret stored for this service
  }
}
```

| Error Class | When Thrown |
|-------------|------------|
| `ItemNotFoundError` | No keychain item matches service + account |
| `AuthFailedError` | Touch ID authentication failed |
| `AuthCancelledError` | User cancelled the Touch ID prompt |
| `BiometricNotAvailable` | No Touch ID hardware or not enrolled |
| `PlatformError` | Not running on macOS |
| `KeychainError` | Base class for all keychain errors |

## CLI

```bash
# Store interactively (prompts for secret)
flnx-keychain set com.myapp.token --biometric --reason "Unlock API key"

# Store from pipe
echo "ghp_abc123" | flnx-keychain set com.myapp.token --biometric

# Retrieve (prints to stdout)
TOKEN=$(flnx-keychain get com.myapp.token)

# Check existence (exit code 0 = exists, 1 = not found)
flnx-keychain has com.myapp.token

# Delete
flnx-keychain delete com.myapp.token
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Item not found |
| 2 | Authentication failed or cancelled |
| 3 | Platform or keychain error |

## Security

- Secrets are read from **stdin**, never from command arguments (prevents shell history leakage)
- Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — no iCloud sync, no backups
- Biometric access uses `.biometryCurrentSet` — invalidates if fingerprints change
- The Swift binary is compiled from source on install

## License

MIT
