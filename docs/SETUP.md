# Setup Guide

## Requirements
- **Windows PC**: Windows 10/11 x64, .NET 8 Runtime / SDK installed.
- **Android Phone**: Android 8.0+ (API 26+), connected to the same Wi-Fi network as the PC.

## Running the Windows Companion
1. Open PowerShell or Command Prompt.
2. Navigate to `windows_companion`:
   ```bash
   cd windows_companion
   dotnet run
   ```
3. The companion will start, minimize to system tray / display the companion dashboard, and start listening on WebSocket port `51234` and UDP discovery port `51235`.
4. If Windows Firewall prompts, select "Allow access" on Private Networks.

## Running the Android App
1. Connect phone via USB with USB debugging enabled, or use an emulator / build APK:
   ```bash
   cd android_app
   flutter run -d <device_id>
   ```
   Or build release/debug APK:
   ```bash
   flutter build apk --debug
   ```
2. Launch the app on your phone.
3. Tap **Discover PCs** to automatically detect your computer over Wi-Fi, or enter your PC's local IP address (shown on the companion dashboard) manually.
4. Follow the pairing instructions (enter the 6-digit code shown on your PC screen).
