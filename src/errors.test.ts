import { describe, expect, test } from "bun:test";
import {
  KeychainError,
  ItemNotFoundError,
  AuthFailedError,
  AuthCancelledError,
  BiometricNotAvailable,
  PlatformError,
} from "./errors.ts";

describe("Error hierarchy", () => {
  test("KeychainError has code and message", () => {
    const err = new KeychainError("test_code", "test message");
    expect(err.message).toBe("test message");
    expect(err.code).toBe("test_code");
    expect(err.name).toBe("KeychainError");
    expect(err).toBeInstanceOf(Error);
  });

  test("ItemNotFoundError extends KeychainError", () => {
    const err = new ItemNotFoundError("not found");
    expect(err.code).toBe("item_not_found");
    expect(err.name).toBe("ItemNotFoundError");
    expect(err).toBeInstanceOf(KeychainError);
    expect(err).toBeInstanceOf(Error);
  });

  test("AuthFailedError extends KeychainError", () => {
    const err = new AuthFailedError("auth failed");
    expect(err.code).toBe("auth_failed");
    expect(err.name).toBe("AuthFailedError");
    expect(err).toBeInstanceOf(KeychainError);
  });

  test("AuthCancelledError extends KeychainError", () => {
    const err = new AuthCancelledError("cancelled");
    expect(err.code).toBe("auth_cancelled");
    expect(err.name).toBe("AuthCancelledError");
    expect(err).toBeInstanceOf(KeychainError);
  });

  test("BiometricNotAvailable extends KeychainError", () => {
    const err = new BiometricNotAvailable("no biometrics");
    expect(err.code).toBe("not_available");
    expect(err.name).toBe("BiometricNotAvailable");
    expect(err).toBeInstanceOf(KeychainError);
  });

  test("PlatformError extends KeychainError", () => {
    const err = new PlatformError("not macOS");
    expect(err.code).toBe("platform_error");
    expect(err.name).toBe("PlatformError");
    expect(err).toBeInstanceOf(KeychainError);
  });
});
