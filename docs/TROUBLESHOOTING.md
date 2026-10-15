# Troubleshooting Guide

## 1. Phone Cannot Discover PC
- Verify both the Windows PC and Android phone are on the exact same Wi-Fi network (check whether PC is on Ethernet and Phone on Wi-Fi with client isolation enabled in router).
- Check Windows Firewall:
  - Open Windows Defender Firewall -> "Allow an app or feature through Windows Defender Firewall".
  - Ensure Universal PC Remote (or .NET Host) has "Private" checked.
  - Or manually allow TCP port `51234` and UDP port `51235`.
- In Android App, use the **Manual IP** input to connect directly using the IP displayed on the companion dashboard.
- If Manual IP works but scanning does not, the Wi-Fi/router is blocking UDP broadcast discovery. This is common on guest networks and networks with client/AP isolation; use Manual IP or disable isolation.

## 2. Pairing Code Not Accepted
- Pairing codes expire after 120 seconds. If expired, tap "Request New Code" in the Android app.
- Check that the companion window displays the code matching the one entered.

## 3. Disconnections / Reconnection
- The Android app retries with increasing delays (1s, 2s, 5s, 10s, 20s, then 30s maximum).
- Returning to the app creates a fresh authenticated WebSocket session. If it still cannot connect, confirm TCP `51234` is allowed through Windows Defender Firewall and try Manual IP.

## 4. Connecting More Than One Android Device
- Multiple paired phones can remain connected at the same time, and each new phone has its own pairing PIN.
- Keyboard and mouse control is intentionally exclusive while a phone is actively using it. Another phone can take over after 10 seconds of input inactivity or when the first phone disconnects. Media and other non-input controls remain available to every paired phone.

## 5. Input Simulation Not Working on Elevated Windows (UAC)
- By default in Windows, standard user applications cannot send simulated mouse/keyboard inputs into elevated admin windows (UIPI - User Interface Privilege Isolation).
- To control admin/UAC elevated tasks, run the Windows Companion as Administrator.
