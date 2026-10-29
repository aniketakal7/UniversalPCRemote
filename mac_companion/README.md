# Universal PC Remote™ — macOS Companion Server
**by Aniket Akal**

This is the official companion server for **macOS** (MacBook, iMac, Mac mini, Mac Studio, Mac Pro). It allows the **Universal PC Remote** Android phone app to seamlessly discover, pair with, and control your Mac over your local Wi-Fi or mobile hotspot.

---

## 🚀 How to Run on Mac

You have two easy ways to run the companion on your Mac:

### Option 1: Quick Launch (Zero Install - Built into macOS)
Every Mac has Python 3 pre-installed. No extra libraries or compiler tools needed:

1. Open the `mac_companion` folder on your Mac.
2. Double-click:
   ```bash
   run_mac.command
   ```
   *(Or open Terminal in this folder and run: `python3 UniversalPCRemote_Mac.py`)*

---

### Option 2: Native .NET 8 Standalone Binary (Apple Silicon & Intel)
If you prefer a compiled native binary:

```bash
# On Apple Silicon (M1, M2, M3, M4):
dotnet publish UniversalPCRemote.Mac.csproj -c Release -r osx-arm64 --self-contained -o dist/mac

# On Intel Macs:
dotnet publish UniversalPCRemote.Mac.csproj -c Release -r osx-x64 --self-contained -o dist/mac
```
Then run `./dist/mac/UniversalPCRemoteMac`.

---

## 🔒 Crucial Mac Permission (One-time Setup)

Because macOS protects against unauthorized remote control, you must grant Accessibility permission so the companion can move the mouse and simulate keystrokes:

1. Open **System Settings** on your Mac.
2. Go to **Privacy & Security** ➔ **Accessibility**.
3. Toggle the switch **ON** for **Terminal** (or **UniversalPCRemoteMac** / **Python**).

---

## 📱 Features Supported on Mac

| Feature | macOS Implementation |
|---|---|
| **Mouse / Touchpad** | Native CoreGraphics cursor warping & click events via `CoreGraphics.framework` |
| **Scrolling** | Smooth vertical and horizontal pixel scroll via `CGEventCreateScrollWheelEvent` |
| **Keyboard** | Text typing and shortcuts (`Cmd+C`, `Cmd+V`, `Cmd+Space`, etc.) via System Events |
| **Media Keys** | Play, Pause, Next, Previous on Apple Music & Spotify |
| **Volume Control** | Volume Up, Volume Down, and Mute via macOS Audio settings |
| **System Power** | Lock Display (`pmset displaysleepnow`), Sleep, Restart, Shutdown |
| **Clipboard** | Bidirectional clipboard sync via macOS `pbcopy` and `pbpaste` |
| **Auto-Discovery** | UDP Beacon on port 51235 (Automatic discovery by the Android app) |
| **Security** | SHA-256 token hashing, 6-digit PIN pairing confirmation banner |
