import { describe, expect, test } from "bun:test";
import { parseArgs } from "util";

describe("CLI argument parsing", () => {
  function parse(argv: string[]) {
    return parseArgs({
      args: argv,
      options: {
        account: { type: "string" },
        biometric: { type: "boolean", default: false },
        reason: { type: "string" },
      },
      strict: false,
    });
  }

  test("parses --account flag", () => {
    const { values } = parse(["--account", "staging"]);
    expect(values.account).toBe("staging");
  });

  test("parses --biometric flag", () => {
    const { values } = parse(["--biometric"]);
    expect(values.biometric).toBe(true);
  });

  test("defaults biometric to false", () => {
    const { values } = parse([]);
    expect(values.biometric).toBe(false);
  });

  test("parses --reason flag", () => {
    const { values } = parse(["--reason", "Unlock API key"]);
    expect(values.reason).toBe("Unlock API key");
  });

  test("parses combined flags", () => {
    const { values } = parse([
      "--account", "prod",
      "--biometric",
      "--reason", "Access token",
    ]);
    expect(values.account).toBe("prod");
    expect(values.biometric).toBe(true);
    expect(values.reason).toBe("Access token");
  });
});
