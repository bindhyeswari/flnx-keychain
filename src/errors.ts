export class KeychainError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "KeychainError";
    this.code = code;
  }
}

export class ItemNotFoundError extends KeychainError {
  constructor(message: string) {
    super("item_not_found", message);
    this.name = "ItemNotFoundError";
  }
}

export class AuthFailedError extends KeychainError {
  constructor(message: string) {
    super("auth_failed", message);
    this.name = "AuthFailedError";
  }
}

export class AuthCancelledError extends KeychainError {
  constructor(message: string) {
    super("auth_cancelled", message);
    this.name = "AuthCancelledError";
  }
}

export class BiometricNotAvailable extends KeychainError {
  constructor(message: string) {
    super("not_available", message);
    this.name = "BiometricNotAvailable";
  }
}

export class PlatformError extends KeychainError {
  constructor(message: string) {
    super("platform_error", message);
    this.name = "PlatformError";
  }
}
