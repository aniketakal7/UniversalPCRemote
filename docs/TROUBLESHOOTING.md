# Troubleshooting Guide

## 1. Phone Cannot Discover PC
- Verify both the Windows PC and Android phone are on the exact same Wi-Fi network (check whether PC is on Ethernet and Phone on Wi-Fi with client isolation enabled in router).
- Check Windows Firewall:
  - Open Windows Defender Firewall -> "Allow an app or feature through Windows Defender Firewall".
  - Ensure Universal PC Remote (or .NET Host) has "Private" checked.
  - Or manually allow TCP port `51234` and UDP port `51235`.
- In Android App, use the **Manual IP** input to connect directly using the IP displayed on the companion dashboard.

## 2. Pairing Code Not Accepted
- Pairing codes expire after 120 seconds. If expired, tap "Request New Code" in the Android app.
- Check that the companion window displays the code matching the one entered.

## 3. Disconnections / Reconnection
- The Android app features an automatic reconnect policy with exponential backoff (1s, 2s, 5s...).
- If the PC goes to sleep or network changes, the companion automatically cleans up abandoned sockets.

## 4. Input Simulation Not Working on Elevated Windows (UAC)
- By default in Windows, standard user applications cannot send simulated mouse/keyboard inputs into elevated admin windows (UIPI - User Interface Privilege Isolation).
- To control admin/UAC elevated tasks, run the Windows Companion as Administrator.
