# Universal PC Remote Architecture

## 1. Overview
Universal PC Remote is a secure, zero-cloud, local-network system for controlling a Windows PC from an Android device.

```
+--------------------------+                 +--------------------------+
|       Android App        |                 |    Windows Companion     |
|       (Flutter/Dart)     |                 |       (C# / .NET 8)      |
|                          |                 |                          |
|  - Material 3 UI         |   Local Wi-Fi   |  - WinForms / Tray UI    |
|  - Touchpad & Keyboard   |  UDP Broadcast  |  - UDP Discovery Beacon  |
|  - Media & System Remotes|<===============>|  - Kestrel WebSocket Svr |
|  - Pairing & Security    |    WebSocket    |  - Command Router        |
|  - WebSocket Client      | (JSON Protocol) |  - Security & Pairing Mgr|
|                          |                 |  - Native Windows APIs   |
+--------------------------+                 +--------------------------+
                                                        |
                                       +----------------+----------------+
                                       |                |                |
                                  Input Subsystem  Media Subsystem  System Subsystem
                                  (SendInput P/Inv)(Media keys/Core)(Lock/Sleep/Pwr)
```

## 2. Windows Companion Architecture
- **Server (`src/Server/`)**: ASP.NET Core Kestrel-backed WebSocket server running asynchronously on a configurable port (default 51234).
- **Discovery (`src/Discovery/`)**: UDP broadcast discovery responder (port 51235) and sender. Broadcasts PC hostname, port, and service UUID.
- **Protocol (`src/Protocol/`)**: Strongly-typed envelopes, command definitions, JSON serialization models.
- **Security & Pairing (`src/Security/`)**:
  - Temporary 6-digit PIN generation with 2-minute expiration.
  - Persistent storage of trusted paired device IDs with cryptographic tokens.
  - Authentication middleware verifying every WebSocket message before execution.
  - Strict command allowlist (no arbitrary shell or process execution).
- **Controllers**:
  - `Input/`: Native Win32 `SendInput` for absolute and relative mouse movement, mouse clicks, mouse scrolling, and virtual keyboard events.
  - `Media/`: Windows virtual key codes (`VK_MEDIA_PLAY_PAUSE`, `VK_VOLUME_UP`, etc.).
  - `System/`: Windows API calls (`LockWorkStation`, `SetSuspendState`, `InitiateSystemShutdownEx`).
  - `Clipboard/`: Thread-safe Win32 OLE clipboard integration.
  - `Macros/`: Safe step runner executing predefined sequential action sets.
- **Diagnostics (`src/Diagnostics/`)**: Subsystem verification engine reporting component pass/fail status.
- **UI (`src/UI/`)**: Clean Windows Forms tray application showing real IP, port, server state, active connections, pairing dialog, logs, and diagnostics.

## 3. Android Flutter Architecture
- **`core/`**: Logging, configuration constants, platform abstractions.
- **`protocol/`**: Request/Response envelope serialization, command models.
- **`network/`**: WebSocket client with automatic reconnection, heartbeat/ping-pong, and error classification.
- **`discovery/`**: UDP discovery client listening for beacons and searching subnet.
- **`pairing/`**: PIN prompt, device token storage using `SharedPreferences`.
- **`state/`**: Reactive connection state machine (`Disconnected`, `Discovering`, `Found`, `Connecting`, `Pairing`, `Authenticated`, `Error`).
- **`features/`**:
  - `touchpad`: Smooth gesture recognizer sending relative `dx`/`dy`, taps, 2-finger scroll, right click.
  - `keyboard`: Text input, modifier toggles (Ctrl, Alt, Shift, Win), function keys.
  - `media`: Media transport buttons with feedback.
  - `system`: System power controls with mandatory confirmation dialogs for dangerous actions.
  - `remotes`: Modular application-specific remotes.
  - `diagnostics`: End-to-end diagnostic ping test screen.
