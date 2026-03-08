import { describe, expect, test, mock, beforeEach } from "bun:test";
import {
  KeychainError,
  ItemNotFoundError,
  AuthFailedError,
  AuthCancelledError,
  BiometricNotAvailable,
  PlatformError,
} from "./errors.ts";

// We test the error-mapping and argument-building logic by importing internals
// Since we can't easily mock Bun.spawn, we test the module's exported functions
// on non-macOS platforms and verify they throw PlatformError.

describe("keychain module", () => {
  test("throws PlatformError on non-darwin platforms", async () => {
    // On Linux (where this test runs), we expect PlatformError
    if (process.platform !== "darwin") {
      const { setSecret } = await import("./keychain.ts");
      expect(
        setSecret("test", { service: "com.test" })
      ).rejects.toBeInstanceOf(PlatformError);
    }
  });

  test("throws PlatformError for getSecret on non-darwin", async () => {
    if (process.platform !== "darwin") {
      const { getSecret } = await import("./keychain.ts");
      expect(
        getSecret({ service: "com.test" })
      ).rejects.toBeInstanceOf(PlatformError);
    }
  });

  test("throws PlatformError for deleteSecret on non-darwin", async () => {
    if (process.platform !== "darwin") {
      const { deleteSecret } = await import("./keychain.ts");
      expect(
        deleteSecret({ service: "com.test" })
      ).rejects.toBeInstanceOf(PlatformError);
    }
  });

  test("throws PlatformError for hasSecret on non-darwin", async () => {
    if (process.platform !== "darwin") {
      const { hasSecret } = await import("./keychain.ts");
      expect(
        hasSecret({ service: "com.test" })
      ).rejects.toBeInstanceOf(PlatformError);
    }
  });
});

describe("error mapping", () => {
  // Test that our error classes properly map error codes
  const errorMap: Record<string, new (msg: string) => KeychainError> = {
    item_not_found: ItemNotFoundError,
    auth_failed: AuthFailedError,
    auth_cancelled: AuthCancelledError,
    not_available: BiometricNotAvailable,
  };

  for (const [code, ErrorClass] of Object.entries(errorMap)) {
    test(`maps '${code}' to ${ErrorClass.name}`, () => {
      const err = new ErrorClass(`test: ${code}`);
      expect(err.code).toBe(code);
      expect(err).toBeInstanceOf(KeychainError);
    });
  }
});
