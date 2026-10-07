# Protocol Architecture & Specifications

Universal PC Remote utilizes a bidirectional, JSON-encoded WebSocket channel over TCP (default port `51234`), complemented by UDP broadcast discovery (port `51235`).

## 1. Connection Life Cycle
```
[Android Client]                               [Windows Companion]
       |                                                |
       |------------- UDP Discovery Ping ------------->| (Port 51235)
       |<------------ UDP Discovery Beacon ------------|
       |                                                |
       |============= WebSocket Connect ===============>| (ws://ip:51234/remote)
       |                                                |
       | [If not paired yet]:                           |
       |-- auth.pair_request (deviceId, name) --------->| Generates 6-digit PIN
       |<-- auth.pair_pending (message) ----------------| Shows PIN on Windows UI
       |-- auth.pair_verify (deviceId, pin) ----------->| Validates PIN
       |<-- auth.pair_success (token, deviceId) --------| Stores trusted device
       |                                                |
       | [If previously paired]:                        |
       |-- auth.authenticate (deviceId, token) -------->| Validates token
       |<-- auth.success -------------------------------| Marks session authenticated
       |                                                |
       | [Command Loop]:                                |
       |-- mouse.move / keyboard.text / etc. ---------->| Executes native Win32 API
       |<-- response (requestId, success, data) --------| Returns result
       |                                                |
       |-- session.ping ------------------------------->| Heartbeat
       |<-- session.pong -------------------------------| Keeps socket alive
```
