export { setSecret, getSecret, deleteSecret, hasSecret, authenticate } from "./keychain.ts";
export {
  KeychainError,
  ItemNotFoundError,
  AuthFailedError,
  AuthCancelledError,
  BiometricNotAvailable,
  PlatformError,
} from "./errors.ts";
export type {
  KeychainItemIdentifier,
  SetOptions,
  GetOptions,
  KeychainResult,
} from "./types.ts";
