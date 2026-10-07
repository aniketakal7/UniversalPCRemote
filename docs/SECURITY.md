# Security Architecture & Rules

## 1. Zero Cloud Dependency
Universal PC Remote operates entirely inside the user's local network (LAN / Wi-Fi). No internet connection is ever required. No telemetry, third-party authentication, or remote relay servers exist.

## 2. No Arbitrary Remote Code Execution (RCE)
By design, the companion server **never** exposes arbitrary command-line or shell execution endpoints.
Commands are strictly mapped to an internal allowlist of known operations:
- `mouse.*` -> Win32 `SendInput` (mouse events only)
- `keyboard.*` -> Win32 `SendInput` (standard key codes and unicode characters)
- `media.*` -> Win32 media keys
- `system.lock` -> Win32 `LockWorkStation`
- `system.sleep` -> Powrprof `SetSuspendState`
- `system.shutdown` / `system.restart` -> `InitiateSystemShutdownEx`

## 3. Pairing and Device Identity
- When a new device attempts to connect, it must perform a pairing handshake.
- The companion server generates a cryptographically random 6-digit PIN and displays it on the Windows Companion UI.
- The PIN expires after 120 seconds.
- Upon correct PIN entry from the Android app, the companion generates a 256-bit authentication token linked to the client's `deviceId`.
- Future sessions authenticate directly using `(deviceId, authToken)`.
- Revocation: The user can disconnect or remove any paired device directly from the Windows companion interface at any time.

## 4. Message Validation and DoS Protection
- WebSocket messages are capped at 64 KB to reject oversized payloads.
- All JSON inputs are deserialized into strongly-typed structures with strict schema validation.
- Connection rate limiting protects against packet floods.
