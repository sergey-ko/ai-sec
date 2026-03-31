# OWASP MASVS v2.1.0 — Level 1 Checklist

Reference: https://mas.owasp.org/MASVS/

MASVS v2 restructured around MAS Testing Profiles. This checklist covers all baseline (L1) requirements across all categories. Each item maps to a MASTG test case.

---

## MASVS-STORAGE: Data Storage

### Storage of Sensitive Data
- [ ] MASVS-STORAGE-1: The app securely stores sensitive data
  - [ ] Sensitive data is not stored in plaintext in local storage (SharedPreferences, NSUserDefaults, plist files, SQLite databases)
  - [ ] Sensitive data is not written to application log files
  - [ ] Sensitive data is not shared with third-party frameworks or libraries unless necessary
  - [ ] Sensitive data is not present in backups (Android: android:allowBackup="false", iOS: excluded from backup)
  - [ ] Sensitive data is not cached in keyboard caches (disable autocorrect for sensitive fields)
  - [ ] Sensitive data is not exposed via clipboard (disable copy/paste for sensitive fields)
  - [ ] Sensitive data is not exposed via IPC mechanisms
  - [ ] Sensitive data is not exposed through screenshots/background snapshots

- [ ] MASVS-STORAGE-2: The app prevents leakage of sensitive data
  - [ ] No sensitive data in system logs (Android Logcat, iOS syslog)
  - [ ] No sensitive data in crash reports
  - [ ] No sensitive data shared with analytics/tracking services without user consent
  - [ ] Application backgrounding screenshots do not contain sensitive data
  - [ ] Text fields containing sensitive data disable auto-suggestions and auto-complete
  - [ ] No sensitive data stored in the pasteboard/clipboard beyond the necessary time

---

## MASVS-CRYPTO: Cryptography

### Cryptographic Implementations
- [ ] MASVS-CRYPTO-1: The app employs current strong cryptography and uses it according to industry best practices
  - [ ] No use of deprecated or insecure algorithms (MD5, SHA1 for signing, DES, 3DES, RC4)
  - [ ] No use of hardcoded cryptographic keys
  - [ ] No use of insufficient key lengths (RSA < 2048, ECC < 224, AES < 128)
  - [ ] No use of insecure modes (ECB mode for symmetric encryption)
  - [ ] No reuse of IVs/nonces with the same key
  - [ ] Cryptographic keys are derived from user-provided secrets using appropriate KDFs (PBKDF2, scrypt, Argon2) with sufficient iterations/cost
  - [ ] Random values are generated using a cryptographically secure random number generator

- [ ] MASVS-CRYPTO-2: The app performs key management according to industry best practices
  - [ ] Cryptographic keys are stored securely (Android Keystore, iOS Keychain)
  - [ ] Keys are not stored alongside the data they protect
  - [ ] Keys are not extractable from secure storage
  - [ ] Key lifecycle is properly managed (generation, storage, rotation, destruction)
  - [ ] Symmetric keys are not derived from predictable sources
  - [ ] Key attestation is used where available (Android key attestation)

---

## MASVS-AUTH: Authentication and Authorization

### Local Authentication
- [ ] MASVS-AUTH-1: The app uses secure authentication and authorization protocols and follows the relevant best practices
  - [ ] Biometric authentication is properly implemented (uses platform APIs, not custom implementations)
  - [ ] Biometric authentication does not rely solely on a boolean return value
  - [ ] Cryptographic operations are gated by biometric authentication (keychain/keystore access)
  - [ ] Session tokens are properly managed (expiration, invalidation on logout)
  - [ ] If custom authentication scheme exists, it is properly reviewed for security flaws
  - [ ] Password/PIN policies follow security best practices (minimum length, complexity appropriate to context)

- [ ] MASVS-AUTH-2: The app performs local authentication securely
  - [ ] Local authentication is not bypassable (cannot be disabled by modifying local data)
  - [ ] Biometric authentication events are tied to a cryptographic operation (unlock a key, not just check a boolean)
  - [ ] Device lock screen is required as a fallback (security level check)
  - [ ] Strong biometric class is preferred (Class 3 on Android, Face ID/Touch ID on iOS)
  - [ ] Authentication retry limits are enforced

- [ ] MASVS-AUTH-3: The app secures sensitive operations with additional authentication
  - [ ] Step-up authentication is required for sensitive operations (payments, data export, account changes)
  - [ ] Re-authentication timeout is appropriate for the sensitivity of the operation
  - [ ] Authentication state cannot be bypassed by tampering with local data

---

## MASVS-NETWORK: Network Communication

### Secure Network Communication
- [ ] MASVS-NETWORK-1: The app secures all network traffic according to the current best practices
  - [ ] All network traffic is encrypted using TLS 1.2 or above
  - [ ] The app does not accept self-signed or untrusted certificates
  - [ ] The app does not bypass certificate validation (no custom TrustManagers accepting all certs on Android, no disabled ATS on iOS without justification)
  - [ ] No cleartext HTTP traffic is permitted (Android: cleartextTrafficPermitted="false", iOS: ATS enabled)
  - [ ] The app properly validates server certificates (hostname verification, chain validation, expiration)
  - [ ] WebView connections also use secure protocols

- [ ] MASVS-NETWORK-2: The app performs identity pinning for all remote endpoints under the developer's control
  - [ ] Certificate or public key pinning is implemented for critical connections
  - [ ] Pinning includes backup pins for key rotation
  - [ ] Pin validation failures result in connection termination, not fallback to unpinned
  - [ ] Pinning configuration is not bypassable without app modification
  - [ ] Pinning exceptions are documented with security justification

---

## MASVS-PLATFORM: Platform Interaction

### Secure Platform Integration
- [ ] MASVS-PLATFORM-1: The app uses IPC mechanisms securely
  - [ ] Exported components (Activities, Services, BroadcastReceivers, ContentProviders on Android) are minimized and protected with appropriate permissions
  - [ ] Custom URL schemes are validated and do not process untrusted input without verification
  - [ ] Deep links/Universal Links are properly validated
  - [ ] JavaScript is disabled in WebViews unless absolutely necessary
  - [ ] WebViews do not allow file access unless required (setAllowFileAccess, setAllowFileAccessFromFileURLs)
  - [ ] Content Providers are not exported unless necessary; if exported, permissions are enforced
  - [ ] Intent filters are specific and do not expose unintended functionality

- [ ] MASVS-PLATFORM-2: The app uses WebViews securely
  - [ ] JavaScript is disabled in WebViews unless explicitly required
  - [ ] WebViews are configured to allow only the minimum set of protocol handlers (no file:// unless needed)
  - [ ] JavaScript native bridges (addJavascriptInterface on Android) are limited to the minimum required API
  - [ ] WebView loads only trusted content (allow list of domains)
  - [ ] No sensitive data is passed via URL parameters in WebView loads
  - [ ] WebView cookie handling follows security best practices

- [ ] MASVS-PLATFORM-3: The app uses the user interface securely
  - [ ] No sensitive data in notifications (lock screen visible notifications)
  - [ ] Custom keyboards are not used for sensitive input (or are properly secured)
  - [ ] Overlay attacks are mitigated (Android: filterTouchesWhenObscured, tapjacking protection)
  - [ ] Auto-fill is disabled for sensitive fields where appropriate
  - [ ] Screenshots/screen capture is disabled for screens showing sensitive data (FLAG_SECURE on Android)

---

## MASVS-CODE: Code Quality

### Secure Code Practices
- [ ] MASVS-CODE-1: The app requires an up-to-date platform version
  - [ ] The app targets a recent SDK version (Android: targetSdkVersion is current or recent, iOS: built with recent Xcode)
  - [ ] The app enforces a minimum supported OS version that receives security updates
  - [ ] Deprecated APIs are not used where secure alternatives exist

- [ ] MASVS-CODE-2: The app has a mechanism for enforcing app updates
  - [ ] The app checks for and prompts updates (or uses platform in-app update mechanisms)
  - [ ] Critical security updates can force users to update before continuing
  - [ ] Version checking does not expose sensitive information

- [ ] MASVS-CODE-3: The app only uses software components without known vulnerabilities
  - [ ] Third-party libraries are up to date and free of known CVEs
  - [ ] A Software Bill of Materials (SBOM) is maintained
  - [ ] Dependency scanning is part of the build pipeline
  - [ ] Unused dependencies are removed

- [ ] MASVS-CODE-4: The app validates and sanitizes all untrusted inputs
  - [ ] All user input is validated before processing
  - [ ] Input validation occurs on the client side AND server side
  - [ ] Format string vulnerabilities are prevented
  - [ ] SQL injection is prevented (parameterized queries or ORM)
  - [ ] XML/JSON injection is prevented
  - [ ] Path traversal attacks are prevented (validate file paths)
  - [ ] WebView input is sanitized to prevent XSS

---

## MASVS-RESILIENCE: Resilience Against Reverse Engineering

### Anti-Tampering and Reverse Engineering (L1 baseline)
- [ ] MASVS-RESILIENCE-1: The app validates the integrity of the platform
  - [ ] The app detects rooted/jailbroken devices and responds appropriately
  - [ ] Root/jailbreak detection uses multiple methods (file checks, system property checks, binary checks)
  - [ ] Detection response is appropriate for the app's risk profile (warn, restrict features, or refuse to run)
  - [ ] Detection is not trivially bypassable (single boolean check)

- [ ] MASVS-RESILIENCE-2: The app implements anti-tampering mechanisms
  - [ ] The app detects code modification/repacking (signature verification)
  - [ ] The app detects the presence of common hooking frameworks (Frida, Xposed, Cydia Substrate)
  - [ ] The app detects debugger attachment and responds appropriately
  - [ ] Integrity checks are distributed throughout the code (not a single check point)
  - [ ] Response to tampering detection is not immediate (delayed response makes correlation harder)

- [ ] MASVS-RESILIENCE-3: The app implements anti-static analysis techniques
  - [ ] Code obfuscation is applied (ProGuard/R8 on Android, compiler flags on iOS)
  - [ ] Sensitive string literals are not stored in plaintext in the binary
  - [ ] Debug symbols are stripped from release builds
  - [ ] Debug logging is removed from release builds

- [ ] MASVS-RESILIENCE-4: The app implements anti-dynamic analysis techniques
  - [ ] Anti-debugging techniques are implemented
  - [ ] Emulator detection is implemented where appropriate
  - [ ] Runtime instrumentation detection (Frida, Xposed) is implemented
  - [ ] Response to dynamic analysis detection degrades gracefully (not obvious crash)

---

## Audit Notes

**How to use this checklist:**
1. Copy this file and rename for the engagement (e.g., `acme-app-masvs-l1.md`)
2. Mark items: `[x]` passed, `[!]` finding raised, `[-]` N/A (with justification)
3. For each `[!]`, create a finding using finding-template.md
4. Note the platform (Android/iOS/both) — some checks are platform-specific
5. Reference MASTG test IDs in findings for reproducibility

**Platform-specific notes:**
- Android: Use MASTG tests prefixed with MSTG-ANDROID-*
- iOS: Use MASTG tests prefixed with MSTG-IOS-*
- Cross-platform frameworks (React Native, Flutter, Xamarin): Test both the framework layer AND native layer

**Tools commonly used:**
- Static: jadx, apktool, Hopper, class-dump, MobSF
- Dynamic: Frida, objection, Burp Suite, mitmproxy
- Platform: Android Studio, Xcode, adb, idevice* tools
