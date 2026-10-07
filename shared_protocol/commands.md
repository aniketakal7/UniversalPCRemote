# Universal Remote Protocol Specification (v1)

## 1. Overview
All client-to-server communication occurs over WebSocket connections in JSON format.
Every message follows a strict envelope structure.

## 2. Request Envelope
```json
{
  "version": 1,
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "command.name",
  "timestamp": 1712500000000,
  "payload": {}
}
```

## 3. Response Envelope
```json
{
  "version": 1,
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "command.name",
  "success": true,
  "data": {},
  "error": null
}
```

## 4. Error Structure
```json
{
  "version": 1,
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "command.name",
  "success": false,
  "data": null,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Session is not authenticated."
  }
}
```

### Standard Error Codes
- `INVALID_JSON`: Malformed JSON text
- `INVALID_ENVELOPE`: Missing required envelope fields or unsupported protocol version
- `UNAUTHORIZED`: Command requires authentication
- `PAIRING_FAILED`: Incorrect PIN or pairing expired
- `UNKNOWN_COMMAND`: Command type not recognized in registry
- `INVALID_PAYLOAD`: Payload validation failed for the command type
- `EXECUTION_FAILED`: Native Windows API or internal handler threw an error
- `RATE_LIMITED`: Too many commands received in interval

## 5. Command Types Reference

### Session & Pairing
- `auth.pair_request`: Initiates pairing; triggers 6-digit code generation on Windows companion.
- `auth.pair_verify`: Verifies code entered on phone; returns session token and registers device.
- `auth.authenticate`: Authenticates with an existing device token.
- `session.ping`: Heartbeat ping from client; server responds with pong.

### Mouse Control
- `mouse.move`: `{ "dx": float, "dy": float }`
- `mouse.click`: `{ "button": "left" | "right" | "middle", "clicks": 1 | 2 }`
- `mouse.down`: `{ "button": "left" | "right" | "middle" }`
- `mouse.up`: `{ "button": "left" | "right" | "middle" }`
- `mouse.scroll`: `{ "dx": float, "dy": float }`

### Keyboard Control
- `keyboard.text`: `{ "text": "string" }`
- `keyboard.key`: `{ "key": "Enter"|"Backspace"|..., "down": bool }`
- `keyboard.combination`: `{ "modifiers": ["ctrl", "alt", "shift", "win"], "key": "c" }`

### Media Control
- `media.play_pause`
- `media.next`
- `media.previous`
- `media.stop`
- `media.volume_up`
- `media.volume_down`
- `media.volume_mute`
- `media.get_status`

### System Control
- `system.lock`
- `system.sleep`
- `system.restart`: `{ "confirm": true }`
- `system.shutdown`: `{ "confirm": true }`
- `system.cancel_shutdown`
- `system.get_info`: Returns hostname, OS version, uptime, battery status

### Clipboard
- `clipboard.get`: Reads text from Windows clipboard
- `clipboard.set`: `{ "text": "string" }`

### Remotes & Macros
- `remote.list`: Lists pre-configured application remotes
- `remote.execute`: `{ "remoteId": "vlc", "actionId": "play_pause" }`
- `macro.list`: Lists available safe macros
- `macro.execute`: `{ "macroId": "presentation_mode" }`

### Diagnostics
- `diagnostics.status`: Returns subsystem status (Input, Audio, System, Network)
