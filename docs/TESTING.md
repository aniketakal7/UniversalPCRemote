# Testing Strategy & Automated Test Suite

## 1. Test Levels
- **Protocol Tests (`tests/windows`)**: Validates serialization, deserialization, invalid envelopes, schema violations, and error payloads.
- **Controller Unit Tests (`tests/windows`)**: Tests pairing engine, token generation, rate limiting, and command router dispatching.
- **Android Unit Tests (`android_app/test/`)**: Tests protocol models, packet encoding, state machine transitions, and reconnection logic.
- **Integration Tests**: Tests end-to-end command roundtrips over a local loopback WebSocket server.

## 2. Running Automated Tests
### Windows (.NET xUnit)
```bash
dotnet test tests/windows/UniversalPCRemote.Tests.csproj
```

### Android (Flutter)
```bash
cd android_app
flutter test
```
