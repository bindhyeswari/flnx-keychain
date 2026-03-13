export interface KeychainItemIdentifier {
  service: string;
  account?: string;
}

export interface SetOptions extends KeychainItemIdentifier {
  biometric?: boolean;
  biometricReason?: string;
}

export interface GetOptions extends KeychainItemIdentifier {
  biometricReason?: string;
}

export interface KeychainResult {
  ok: boolean;
  value?: string;
  exists?: boolean;
  error?: string;
  message?: string;
}

export interface ExecConfig {
  service: string;
  secrets: Record<string, string>; // ENV_VAR → account
  biometric?: boolean; // Require Touch ID before accessing secrets
}
