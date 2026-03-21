import Foundation
import Security
import LocalAuthentication

// MARK: - JSON Output

struct JSONResponse {
    static func success(_ fields: [String: Any] = [:]) -> String {
        var result: [String: Any] = ["ok": true]
        for (key, value) in fields { result[key] = value }
        return serialize(result)
    }

    static func error(code: String, message: String) -> String {
        return serialize(["ok": false, "error": code, "message": message])
    }

    private static func serialize(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"ok\":false,\"error\":\"internal\",\"message\":\"JSON serialization failed\"}"
        }
        return str
    }
}

// MARK: - Argument Parsing

struct Args {
    let command: String
    let service: String
    let account: String
    let biometric: Bool
    let biometricReason: String

    static func parse() -> Args? {
        let args = CommandLine.arguments
        guard args.count >= 2 else { return nil }

        let command = args[1]
        var service: String?
        var account = "default"
        var biometric = false
        var biometricReason = "authenticate to access secret"

        var i = 2
        while i < args.count {
            switch args[i] {
            case "--service":
                i += 1; if i < args.count { service = args[i] }
            case "--account":
                i += 1; if i < args.count { account = args[i] }
            case "--biometric":
                biometric = true
            case "--biometric-reason":
                i += 1; if i < args.count { biometricReason = args[i] }
            default:
                break
            }
            i += 1
        }

        // auth command doesn't require service
        if command == "auth" {
            return Args(command: command, service: "", account: account,
                        biometric: biometric, biometricReason: biometricReason)
        }
        guard let svc = service else { return nil }
        return Args(command: command, service: svc, account: account,
                    biometric: biometric, biometricReason: biometricReason)
    }
}

// MARK: - Keychain Operations

func setItem(args: Args) {
    // Read secret from stdin
    guard let inputData = FileHandle.standardInput.readDataToEndOfFile() as Data?,
          var secret = String(data: inputData, encoding: .utf8) else {
        print(JSONResponse.error(code: "keychain_error", message: "Failed to read secret from stdin"))
        exit(3)
    }

    // Trim trailing whitespace/newlines
    secret = secret.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !secret.isEmpty else {
        print(JSONResponse.error(code: "keychain_error", message: "Empty secret provided"))
        exit(3)
    }

    guard let secretData = secret.data(using: .utf8) else {
        print(JSONResponse.error(code: "keychain_error", message: "Failed to encode secret"))
        exit(3)
    }

    // Authenticate with Touch ID before storing, so the user confirms the write
    if args.biometric {
        let context = LAContext()
        context.localizedReason = args.biometricReason

        let semaphore = DispatchSemaphore(value: 0)
        var authSuccess = false
        var authError: Error?

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: args.biometricReason) { success, error in
            authSuccess = success
            authError = error
            semaphore.signal()
        }
        semaphore.wait()

        if !authSuccess {
            if let laError = authError as? LAError {
                switch laError.code {
                case .userCancel:
                    print(JSONResponse.error(code: "auth_cancelled", message: "User cancelled authentication"))
                    exit(2)
                case .biometryNotAvailable:
                    print(JSONResponse.error(code: "not_available", message: "Biometrics not available"))
                    exit(3)
                case .biometryNotEnrolled:
                    print(JSONResponse.error(code: "not_available", message: "No biometrics enrolled"))
                    exit(3)
                default:
                    print(JSONResponse.error(code: "auth_failed", message: "Authentication failed: \(laError.localizedDescription)"))
                    exit(2)
                }
            }
            print(JSONResponse.error(code: "auth_failed", message: "Authentication failed"))
            exit(2)
        }
    }

    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: args.service,
        kSecAttrAccount as String: args.account,
        kSecValueData as String: secretData,
    ]

    if args.biometric {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            let msg = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            print(JSONResponse.error(code: "not_available", message: "Cannot create biometric access control: \(msg)"))
            exit(3)
        }
        query[kSecAttrAccessControl as String] = access
    } else {
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }

    var status = SecItemAdd(query as CFDictionary, nil)

    if status == errSecDuplicateItem {
        // Update existing item
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: args.service,
            kSecAttrAccount as String: args.account,
        ]
        var updateAttrs: [String: Any] = [
            kSecValueData as String: secretData,
        ]
        if args.biometric {
            var error: Unmanaged<CFError>?
            if let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                &error
            ) {
                updateAttrs[kSecAttrAccessControl as String] = access
            }
        }
        status = SecItemUpdate(searchQuery as CFDictionary, updateAttrs as CFDictionary)
    }

    if status == errSecSuccess {
        print(JSONResponse.success())
    } else {
        let hint = status == -34018 ? " — binary is missing keychain entitlements. Reinstall the package or run: codesign --force --sign - --entitlements native/keychain-helper/keychain-helper.entitlements bin/keychain-helper" : ""
        print(JSONResponse.error(code: "keychain_error", message: "Keychain error: OSStatus \(status)\(hint)"))
        exit(3)
    }
}

func getItem(args: Args) {
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: args.service,
        kSecAttrAccount as String: args.account,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    if args.biometric {
        let context = LAContext()
        context.localizedReason = args.biometricReason

        let semaphore = DispatchSemaphore(value: 0)
        var authSuccess = false
        var authError: Error?

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: args.biometricReason) { success, error in
            authSuccess = success
            authError = error
            semaphore.signal()
        }
        semaphore.wait()

        if !authSuccess {
            if let laError = authError as? LAError {
                switch laError.code {
                case .userCancel:
                    print(JSONResponse.error(code: "auth_cancelled", message: "User cancelled authentication"))
                    exit(2)
                case .biometryNotAvailable:
                    print(JSONResponse.error(code: "not_available", message: "Biometrics not available"))
                    exit(3)
                case .biometryNotEnrolled:
                    print(JSONResponse.error(code: "not_available", message: "No biometrics enrolled"))
                    exit(3)
                default:
                    print(JSONResponse.error(code: "auth_failed", message: "Authentication failed: \(laError.localizedDescription)"))
                    exit(2)
                }
            }
            print(JSONResponse.error(code: "auth_failed", message: "Authentication failed"))
            exit(2)
        }

        query[kSecUseAuthenticationContext as String] = context
    }

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            print(JSONResponse.error(code: "keychain_error", message: "Failed to decode secret"))
            exit(3)
        }
        print(JSONResponse.success(["value": value]))
    case errSecItemNotFound:
        print(JSONResponse.error(code: "item_not_found", message: "No keychain item found for service '\(args.service)' account '\(args.account)'"))
        exit(1)
    case errSecAuthFailed:
        print(JSONResponse.error(code: "auth_failed", message: "Authentication failed"))
        exit(2)
    case errSecUserCanceled:
        print(JSONResponse.error(code: "auth_cancelled", message: "User cancelled authentication"))
        exit(2)
    default:
        let hint = status == -34018 ? " — binary is missing keychain entitlements. Reinstall the package or run: codesign --force --sign - --entitlements native/keychain-helper/keychain-helper.entitlements bin/keychain-helper" : ""
        print(JSONResponse.error(code: "keychain_error", message: "Keychain error: OSStatus \(status)\(hint)"))
        exit(3)
    }
}

func deleteItem(args: Args) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: args.service,
        kSecAttrAccount as String: args.account,
    ]

    let status = SecItemDelete(query as CFDictionary)

    switch status {
    case errSecSuccess:
        print(JSONResponse.success())
    case errSecItemNotFound:
        print(JSONResponse.error(code: "item_not_found", message: "No keychain item found for service '\(args.service)' account '\(args.account)'"))
        exit(1)
    default:
        let hint = status == -34018 ? " — binary is missing keychain entitlements. Reinstall the package or run: codesign --force --sign - --entitlements native/keychain-helper/keychain-helper.entitlements bin/keychain-helper" : ""
        print(JSONResponse.error(code: "keychain_error", message: "Keychain error: OSStatus \(status)\(hint)"))
        exit(3)
    }
}

func hasItem(args: Args) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: args.service,
        kSecAttrAccount as String: args.account,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    let status = SecItemCopyMatching(query as CFDictionary, nil)

    switch status {
    case errSecSuccess:
        print(JSONResponse.success(["exists": true]))
    case errSecItemNotFound:
        print(JSONResponse.success(["exists": false]))
    default:
        let hint = status == -34018 ? " — binary is missing keychain entitlements. Reinstall the package or run: codesign --force --sign - --entitlements native/keychain-helper/keychain-helper.entitlements bin/keychain-helper" : ""
        print(JSONResponse.error(code: "keychain_error", message: "Keychain error: OSStatus \(status)\(hint)"))
        exit(3)
    }
}

func authenticate(args: Args) {
    let context = LAContext()
    var error: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        let msg = error?.localizedDescription ?? "Biometrics not available"
        print(JSONResponse.error(code: "not_available", message: msg))
        exit(3)
    }

    let semaphore = DispatchSemaphore(value: 0)
    var authSuccess = false
    var authError: Error?

    context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: args.biometricReason) { success, err in
        authSuccess = success
        authError = err
        semaphore.signal()
    }
    semaphore.wait()

    if authSuccess {
        print(JSONResponse.success())
    } else {
        if let laError = authError as? LAError {
            switch laError.code {
            case .userCancel:
                print(JSONResponse.error(code: "auth_cancelled", message: "User cancelled authentication"))
                exit(2)
            default:
                print(JSONResponse.error(code: "auth_failed", message: "Authentication failed: \(laError.localizedDescription)"))
                exit(2)
            }
        }
        print(JSONResponse.error(code: "auth_failed", message: "Authentication failed"))
        exit(2)
    }
}

// MARK: - Main

guard let args = Args.parse() else {
    fputs("Usage: keychain-helper <set|get|delete|has> --service <name> [--account <name>] [--biometric] [--biometric-reason <text>]\n", stderr)
    print(JSONResponse.error(code: "keychain_error", message: "Invalid arguments"))
    exit(3)
}

switch args.command {
case "set":
    setItem(args: args)
case "get":
    getItem(args: args)
case "delete":
    deleteItem(args: args)
case "has":
    hasItem(args: args)
case "auth":
    authenticate(args: args)
default:
    print(JSONResponse.error(code: "keychain_error", message: "Unknown command: \(args.command)"))
    exit(3)
}
