import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import {
  KeychainError,
  ItemNotFoundError,
  AuthFailedError,
  AuthCancelledError,
  BiometricNotAvailable,
  PlatformError,
} from "./errors.ts";
import type {
  KeychainItemIdentifier,
  SetOptions,
  GetOptions,
  KeychainResult,
} from "./types.ts";

const TIMEOUT_MS = 30_000;

function getBinaryPath(): string {
  const currentDir = typeof import.meta.dir === "string"
    ? import.meta.dir
    : dirname(fileURLToPath(import.meta.url));
  return resolve(currentDir, "..", "bin", "keychain-helper");
}

let binaryPathCache: string | null = null;

function resolveBinary(): string {
  if (binaryPathCache) return binaryPathCache;

  if (process.platform !== "darwin") {
    throw new PlatformError("keychain-touch-id requires macOS");
  }

  const binPath = getBinaryPath();

  try {
    const stat = Bun.file(binPath);
    if (!stat.size) throw new Error();
  } catch {
    throw new PlatformError(
      `keychain-helper binary not found at ${binPath}. Run 'npm rebuild' or 'bun run build:swift'.`
    );
  }

  binaryPathCache = binPath;
  return binPath;
}

function throwForError(result: KeychainResult): never {
  const msg = result.message ?? "Unknown keychain error";
  switch (result.error) {
    case "item_not_found":
      throw new ItemNotFoundError(msg);
    case "auth_failed":
      throw new AuthFailedError(msg);
    case "auth_cancelled":
      throw new AuthCancelledError(msg);
    case "not_available":
      throw new BiometricNotAvailable(msg);
    default:
      throw new KeychainError(result.error ?? "unknown", msg);
  }
}

async function exec(
  args: string[],
  stdin?: string
): Promise<KeychainResult> {
  const binPath = resolveBinary();

  const proc = Bun.spawn([binPath, ...args], {
    stdin: stdin != null ? new Blob([stdin]) : undefined,
    stdout: "pipe",
    stderr: "pipe",
  });

  const timeoutPromise = new Promise<never>((_, reject) => {
    setTimeout(() => {
      proc.kill();
      reject(new KeychainError("timeout", "keychain-helper timed out"));
    }, TIMEOUT_MS);
  });

  const exitCode = await Promise.race([proc.exited, timeoutPromise]);

  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();

  if (!stdout.trim()) {
    if (exitCode !== 0) {
      throw new KeychainError(
        "keychain_error",
        stderr.trim() || `keychain-helper exited with code ${exitCode}`
      );
    }
    throw new KeychainError("keychain_error", "Empty response from keychain-helper");
  }

  let result: KeychainResult;
  try {
    result = JSON.parse(stdout.trim());
  } catch {
    throw new KeychainError("keychain_error", `Invalid JSON from keychain-helper: ${stdout.trim()}`);
  }

  if (!result.ok) {
    throwForError(result);
  }

  return result;
}

function buildArgs(
  command: string,
  options: KeychainItemIdentifier & { biometric?: boolean; biometricReason?: string }
): string[] {
  const args = [command, "--service", options.service];
  if (options.account) args.push("--account", options.account);
  if (options.biometric) args.push("--biometric");
  if (options.biometricReason) args.push("--biometric-reason", options.biometricReason);
  return args;
}

export async function setSecret(secret: string, options: SetOptions): Promise<void> {
  await exec(buildArgs("set", options), secret);
}

export async function getSecret(options: GetOptions): Promise<string> {
  const result = await exec(buildArgs("get", options));
  return result.value!;
}

export async function deleteSecret(options: KeychainItemIdentifier): Promise<void> {
  await exec(buildArgs("delete", options));
}

export async function hasSecret(options: KeychainItemIdentifier): Promise<boolean> {
  const result = await exec(buildArgs("has", options));
  return result.exists!;
}
