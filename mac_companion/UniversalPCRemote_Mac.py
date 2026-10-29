#!/usr/bin/env python3
"""
Universal PC Remote™ for macOS — Pure Python Companion Server
by Aniket Akal

Features:
- Zero external dependencies: Uses only macOS built-in Python 3 standard library
- Native mouse, scroll, and click control via macOS CoreGraphics (ctypes)
- Media, volume, power, and clipboard control via macOS System Events & osascript
- UDP discovery beacon on port 51235
- RFC6455 WebSocket server on port 51234
"""

import asyncio
import base64
import ctypes
import hashlib
import json
import os
import platform
import random
import socket
import struct
import subprocess
import sys
import time

PORT_WS = 51234
PORT_UDP = 51235
WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

# --- macOS CoreGraphics P/Invoke via ctypes ---
try:
    cg = ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
    cf = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")

    class CGPoint(ctypes.Structure):
        _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]

    cg.CGEventCreate.restype = ctypes.c_void_p
    cg.CGEventCreate.argtypes = [ctypes.c_void_p]

    cg.CGEventGetLocation.restype = CGPoint
    cg.CGEventGetLocation.argtypes = [ctypes.c_void_p]

    cg.CGWarpMouseCursorPosition.restype = None
    cg.CGWarpMouseCursorPosition.argtypes = [CGPoint]

    cg.CGEventCreateMouseEvent.restype = ctypes.c_void_p
    cg.CGEventCreateMouseEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint32, CGPoint, ctypes.c_uint32]

    cg.CGEventPost.restype = None
    cg.CGEventPost.argtypes = [ctypes.c_uint32, ctypes.c_void_p]

    cg.CGEventCreateScrollWheelEvent.restype = ctypes.c_void_p
    cg.CGEventCreateScrollWheelEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_int32, ctypes.c_int32]

    cf.CFRelease.restype = None
    cf.CFRelease.argtypes = [ctypes.c_void_p]

    HAS_CG = True
except Exception:
    HAS_CG = False


def get_mouse_pos():
    if not HAS_CG:
        return 0.0, 0.0
    ev = cg.CGEventCreate(None)
    if not ev:
        return 0.0, 0.0
    loc = cg.CGEventGetLocation(ev)
    cf.CFRelease(ev)
    return loc.x, loc.y


def move_mouse(dx, dy, sens=1.0):
    if not HAS_CG:
        return
    x, y = get_mouse_pos()
    nx = max(0.0, x + (dx * sens))
    ny = max(0.0, y + (dy * sens))
    pt = CGPoint(nx, ny)
    cg.CGWarpMouseCursorPosition(pt)
    ev = cg.CGEventCreateMouseEvent(None, 5, pt, 0) # 5 = kCGEventMouseMoved
    if ev:
        cg.CGEventPost(0, ev)
        cf.CFRelease(ev)


def mouse_click(button="left", clicks=1):
    if not HAS_CG:
        return
    x, y = get_mouse_pos()
    pt = CGPoint(x, y)
    is_right = button.lower() == "right"
    down_type = 3 if is_right else 1
    up_type = 4 if is_right else 2
    btn = 1 if is_right else 0

    for _ in range(clicks):
        d = cg.CGEventCreateMouseEvent(None, down_type, pt, btn)
        if d:
            cg.CGEventPost(0, d)
            cf.CFRelease(d)
        time.sleep(0.015)
        u = cg.CGEventCreateMouseEvent(None, up_type, pt, btn)
        if u:
            cg.CGEventPost(0, u)
            cf.CFRelease(u)
        time.sleep(0.03)


def mouse_scroll(dx, dy):
    if not HAS_CG:
        return
    ev = cg.CGEventCreateScrollWheelEvent(None, 0, 2, int(dy * 6), int(dx * 6))
    if ev:
        cg.CGEventPost(0, ev)
        cf.CFRelease(ev)


def run_osascript(script):
    try:
        subprocess.run(["osascript", "-e", script], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def run_osascript_output(script):
    try:
        res = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, check=False)
        return res.stdout.strip()
    except Exception:
        return ""


# --- Pairing & Security ---
trusted_devices = {}
active_pairings = {}

def get_storage_path():
    p = os.path.expanduser("~/.universalpcremote")
    os.makedirs(p, exist_ok=True)
    return os.path.join(p, "trusted_devices.json")

def load_trusted():
    global trusted_devices
    sp = get_storage_path()
    if os.path.exists(sp):
        try:
            with open(sp, "r", encoding="utf-8") as f:
                trusted_devices = json.load(f)
        except Exception:
            trusted_devices = {}

def save_trusted():
    sp = get_storage_path()
    try:
        with open(sp, "w", encoding="utf-8") as f:
            json.dump(trusted_devices, f, indent=2)
    except Exception:
        pass


# --- Network & IPs ---
def get_local_ips():
    ips = []
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ips.append(s.getsockname()[0])
        s.close()
    except Exception:
        pass
    if not ips:
        ips.append("127.0.0.1")
    return ips


# --- UDP Discovery Beacon ---
async def udp_beacon():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    s.setblocking(False)

    while True:
        try:
            payload = {
                "service": "UniversalPCRemote",
                "type": "discovery.announcement",
                "version": 1,
                "pcName": platform.node(),
                "port": PORT_WS,
                "os": "macOS",
                "addresses": get_local_ips(),
                "isHotspot": False
            }
            data = json.dumps(payload).encode("utf-8")
            s.sendto(data, ("<broadcast>", PORT_UDP))
        except Exception:
            pass
        await asyncio.sleep(2.5)


# --- Minimal RFC6455 WebSocket Handshake & Frame parser ---
async def read_ws_frame(reader):
    header = await reader.readexactly(2)
    b1, b2 = header[0], header[1]
    opcode = b1 & 0x0F
    is_masked = bool(b2 & 0x80)
    payload_len = b2 & 0x7F

    if opcode == 0x8:  # Close frame
        return None

    if payload_len == 126:
        ext = await reader.readexactly(2)
        payload_len = struct.unpack("!H", ext)[0]
    elif payload_len == 127:
        ext = await reader.readexactly(8)
        payload_len = struct.unpack("!Q", ext)[0]

    mask_key = await reader.readexactly(4) if is_masked else None
    data = await reader.readexactly(payload_len)

    if is_masked:
        data = bytearray(b ^ mask_key[i % 4] for i, b in enumerate(data))

    return data.decode("utf-8", errors="ignore")


def make_ws_frame(text):
    data = text.encode("utf-8")
    length = len(data)
    frame = bytearray([0x81]) # FIN + Text
    if length < 126:
        frame.append(length)
    elif length <= 0xFFFF:
        frame.append(126)
        frame.extend(struct.pack("!H", length))
    else:
        frame.append(127)
        frame.extend(struct.pack("!Q", length))
    frame.extend(data)
    return bytes(frame)


async def handle_client(reader, writer):
    # Perform HTTP / WebSocket Handshake
    request = (await reader.readuntil(b"\r\n\r\n")).decode("utf-8", errors="ignore")
    headers = {}
    for line in request.split("\r\n")[1:]:
        if ":" in line:
            k, v = line.split(":", 1)
            headers[k.strip().lower()] = v.strip()

    sec_key = headers.get("sec-websocket-key")
    if not sec_key:
        writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"running\",\"os\":\"macOS\"}")
        await writer.drain()
        writer.close()
        return

    accept = base64.b64encode(hashlib.sha1((sec_key + WS_GUID).encode()).digest()).decode()
    resp = f"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n\r\n"
    writer.write(resp.encode("utf-8"))
    await writer.drain()

    session_authenticated = False
    current_device_id = None

    async def send_response(req_id, cmd_type, success=True, data=None, error=None):
        payload = {
            "version": 1,
            "requestId": req_id,
            "type": cmd_type,
            "success": success,
            "data": data,
            "error": error
        }
        writer.write(make_ws_frame(json.dumps(payload)))
        await writer.drain()

    try:
        while True:
            msg = await read_ws_frame(reader)
            if msg is None:
                break

            try:
                env = json.loads(msg)
            except Exception:
                continue

            req_id = env.get("requestId", "")
            cmd = env.get("type", "")
            p = env.get("payload", {}) or {}

            # Auth commands
            if cmd == "auth.pair_request":
                device_id = p.get("deviceId", "unknown")
                device_name = p.get("deviceName", "Device")
                pin = f"{random.randint(100000, 999999)}"
                active_pairings[device_id] = {"pin": pin, "name": device_name, "exp": time.time() + 120}

                print("\n" + "═" * 65)
                print(f"  >>>  PAIRING CODE ACTIVE:  {pin}  <<<")
                print(f"  Device: {device_name}")
                print("  Enter this 6-digit code on your phone within 120s.")
                print("═" * 65 + "\n")

                await send_response(req_id, cmd, True, {"pinRequired": True, "expiresInSeconds": 120})

            elif cmd == "auth.pair_verify":
                device_id = p.get("deviceId")
                pin = str(p.get("pin", "")).strip()
                req = active_pairings.get(device_id)

                if req and req["pin"] == pin and time.time() < req["exp"]:
                    token = os.urandom(24).hex()
                    trusted_devices[device_id] = {"token": token, "name": req["name"]}
                    save_trusted()
                    session_authenticated = True
                    current_device_id = device_id
                    print(f"[Security] ✓ Device '{req['name']}' successfully paired!")
                    await send_response(req_id, cmd, True, {"authenticated": True, "authToken": token})
                else:
                    await send_response(req_id, cmd, False, error={"code": "PAIRING_FAILED", "message": "Invalid or expired PIN."})

            elif cmd == "auth.authenticate":
                device_id = p.get("deviceId")
                token = p.get("authToken")
                if trusted_devices.get(device_id, {}).get("token") == token:
                    session_authenticated = True
                    current_device_id = device_id
                    await send_response(req_id, cmd, True, {"authenticated": True})
                else:
                    await send_response(req_id, cmd, False, error={"code": "UNAUTHORIZED", "message": "Invalid token."})

            elif cmd == "session.ping":
                await send_response(req_id, "session.pong", True, {"machine": platform.node(), "os": "macOS"})

            # Require auth for rest
            elif not session_authenticated:
                await send_response(req_id, cmd, False, error={"code": "UNAUTHORIZED", "message": "Please pair first."})

            # Mouse
            elif cmd == "mouse.move":
                move_mouse(float(p.get("dx", 0)), float(p.get("dy", 0)), float(p.get("sensitivity", 1.0)))
            elif cmd == "mouse.click":
                mouse_click(p.get("button", "left"), int(p.get("clicks", 1)))
            elif cmd == "mouse.scroll":
                mouse_scroll(float(p.get("dx", 0)), float(p.get("dy", 0)))

            # Keyboard
            elif cmd == "keyboard.text":
                txt = p.get("text", "").replace('"', '\\"')
                run_osascript(f'tell application "System Events" to keystroke "{txt}"')
            elif cmd == "keyboard.key":
                k = p.get("key", "").lower()
                kmap = {"enter": 36, "return": 36, "tab": 48, "space": 49, "backspace": 51, "delete": 51, "escape": 53}
                if k in kmap:
                    run_osascript(f'tell application "System Events" to key code {kmap[k]}')
            elif cmd == "keyboard.combination":
                k = p.get("key", "").replace('"', '\\"')
                mods = [f"{m.lower()} down" for m in p.get("modifiers", []) if m.lower() in ("command", "control", "option", "shift")]
                mod_str = f" using {{{', '.join(mods)}}}" if mods else ""
                run_osascript(f'tell application "System Events" to keystroke "{k}"{mod_str}')

            # Media
            elif cmd == "media.play_pause":
                run_osascript('tell application "Music" to playpause')
            elif cmd == "media.next":
                run_osascript('tell application "Music" to next track')
            elif cmd == "media.previous":
                run_osascript('tell application "Music" to previous track')
            elif cmd == "media.volume_up":
                run_osascript('set volume output volume ((output volume of (get volume settings)) + 6)')
            elif cmd == "media.volume_down":
                run_osascript('set volume output volume ((output volume of (get volume settings)) - 6)')
            elif cmd == "media.volume_mute":
                run_osascript('set volume output muted (not (output muted of (get volume settings)))')
            elif cmd == "media.get_status":
                vol = run_osascript_output('output volume of (get volume settings)')
                await send_response(req_id, cmd, True, {"volume": int(vol or 50), "state": "ready"})

            # System
            elif cmd == "system.lock":
                run_osascript('tell application "System Events" to key code 12 using {control down, command down}')
                await send_response(req_id, cmd, True, {"locked": True})
            elif cmd == "system.sleep":
                run_osascript('tell application "System Events" to sleep')
                await send_response(req_id, cmd, True, {"slept": True})
            elif cmd == "system.restart":
                run_osascript('tell application "System Events" to restart')
                await send_response(req_id, cmd, True, {"scheduled": True})
            elif cmd == "system.shutdown":
                run_osascript('tell application "System Events" to shut down')
                await send_response(req_id, cmd, True, {"scheduled": True})
            elif cmd == "system.get_info":
                await send_response(req_id, cmd, True, {
                    "machineName": platform.node(),
                    "os": "macOS",
                    "version": platform.mac_ver()[0] or platform.platform()
                })

            # Clipboard
            elif cmd == "clipboard.get":
                txt = subprocess.run(["pbpaste"], capture_output=True, text=True, check=False).stdout
                await send_response(req_id, cmd, True, {"text": txt})
            elif cmd == "clipboard.set":
                txt = p.get("text", "")
                proc = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
                proc.communicate(txt.encode("utf-8"))
                await send_response(req_id, cmd, True, {"set": True})

    except Exception:
        pass
    finally:
        writer.close()


async def main():
    load_trusted()
    ips = get_local_ips()

    print("\033[96m")
    print("╔═══════════════════════════════════════════════════════════════════╗")
    print("║       Universal PC Remote™ for macOS — Companion Server           ║")
    print("║                      by Aniket Akal                               ║")
    print("╚═══════════════════════════════════════════════════════════════════╝")
    print("\033[0m")
    print(f"  Mac Hostname:   {platform.node()}")
    print(f"  macOS Version:  {platform.mac_ver()[0] or platform.platform()}")
    print(f"  WebSocket Port: {PORT_WS}")
    print(f"  Discovery Port: {PORT_UDP} (UDP)")
    print(f"  IP Address(es): {', '.join(ips)}")
    print()
    print("  \033[92m● Server is running & broadcasting discovery.\033[0m")
    print("  Connect your Android phone app to start controlling this Mac.")
    print("  Press Ctrl+C to quit.")
    print("─" * 67)

    server = await asyncio.start_server(handle_client, "0.0.0.0", PORT_WS)
    asyncio.create_task(udp_beacon())

    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nCompanion server stopped. Goodbye!")
