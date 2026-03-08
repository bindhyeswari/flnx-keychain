#!/usr/bin/env bun
import { parseArgs } from "util";
import { setSecret, getSecret, deleteSecret, hasSecret } from "./keychain.ts";
import {
  KeychainError,
  ItemNotFoundError,
  AuthFailedError,
  AuthCancelledError,
} from "./errors.ts";

const USAGE = `Usage: flnx-keychain <command> <service> [options]

Commands:
  set <service>     Store a secret in the Keychain
  get <service>     Retrieve a secret (prints to stdout)
  delete <service>  Remove a secret from the Keychain
  has <service>     Check if a secret exists

Options:
  --account <name>   Keychain account label (default: "default")
  --biometric        Require Touch ID to access this item
  --reason <text>    Message shown in the Touch ID dialog
  --help             Show this help message`;

function die(message: string, code: number): never {
  process.stderr.write(`Error: ${message}\n`);
  process.exit(code);
}

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf-8").trimEnd();
}

async function promptSecret(): Promise<string> {
  process.stderr.write("Enter secret: ");

  return new Promise((resolve) => {
    let input = "";
    process.stdin.setRawMode?.(true);
    process.stdin.resume();
    process.stdin.setEncoding("utf-8");

    process.stdin.on("data", (char: string) => {
      if (char === "\n" || char === "\r") {
        process.stderr.write("\n");
        process.stdin.setRawMode?.(false);
        process.stdin.pause();
        resolve(input);
      } else if (char === "\u0003") {
        // Ctrl+C
        process.stderr.write("\n");
        process.exit(130);
      } else if (char === "\u007f" || char === "\b") {
        // Backspace
        if (input.length > 0) input = input.slice(0, -1);
      } else {
        input += char;
      }
    });
  });
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
    console.log(USAGE);
    process.exit(0);
  }

  const command = args[0];
  const service = args[1];

  if (!service) {
    die(`Missing service argument. Run 'flnx-keychain --help' for usage.`, 3);
  }

  const { values } = parseArgs({
    args: args.slice(2),
    options: {
      account: { type: "string" },
      biometric: { type: "boolean", default: false },
      reason: { type: "string" },
    },
    strict: false,
  });

  const account = values.account as string | undefined;
  const biometric = values.biometric as boolean;
  const reason = values.reason as string | undefined;

  try {
    switch (command) {
      case "set": {
        let secret: string;
        if (process.stdin.isTTY) {
          secret = await promptSecret();
        } else {
          secret = await readStdin();
        }
        if (!secret) die("Empty secret provided", 3);
        await setSecret(secret, {
          service,
          account,
          biometric,
          biometricReason: reason,
        });
        process.stderr.write("Secret stored successfully\n");
        break;
      }

      case "get": {
        const value = await getSecret({
          service,
          account,
          biometricReason: reason,
        });
        process.stdout.write(value);
        break;
      }

      case "delete": {
        await deleteSecret({ service, account });
        process.stderr.write("Secret deleted successfully\n");
        break;
      }

      case "has": {
        const exists = await hasSecret({ service, account });
        process.stdout.write(exists ? "true\n" : "false\n");
        process.exit(exists ? 0 : 1);
        break;
      }

      default:
        die(`Unknown command: ${command}. Run 'flnx-keychain --help' for usage.`, 3);
    }
  } catch (err) {
    if (err instanceof ItemNotFoundError) {
      die(err.message, 1);
    } else if (err instanceof AuthFailedError || err instanceof AuthCancelledError) {
      die(err.message, 2);
    } else if (err instanceof KeychainError) {
      die(err.message, 3);
    }
    throw err;
  }
}

main();
