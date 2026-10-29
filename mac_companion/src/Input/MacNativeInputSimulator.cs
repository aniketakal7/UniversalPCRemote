using System.Diagnostics;
using System.Runtime.InteropServices;
using UniversalPCRemote.Mac.Logging;

namespace UniversalPCRemote.Mac.Input;

public class MacNativeInputSimulator
{
    private static readonly Lazy<MacNativeInputSimulator> _instance = new(() => new MacNativeInputSimulator());
    public static MacNativeInputSimulator Instance => _instance.Value;

    [StructLayout(LayoutKind.Sequential)]
    public struct CGPoint
    {
        public double X;
        public double Y;
    }

    private const string CoreGraphicsLib = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics";
    private const string CoreFoundationLib = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";

    [DllImport(CoreGraphicsLib)]
    private static extern IntPtr CGEventCreate(IntPtr source);

    [DllImport(CoreGraphicsLib)]
    private static extern CGPoint CGEventGetLocation(IntPtr eventHandle);

    [DllImport(CoreGraphicsLib)]
    private static extern void CGWarpMouseCursorPosition(CGPoint newCursorPosition);

    [DllImport(CoreGraphicsLib)]
    private static extern IntPtr CGEventCreateMouseEvent(
        IntPtr source,
        uint mouseType,
        CGPoint mouseCursorPosition,
        uint mouseButton);

    [DllImport(CoreGraphicsLib)]
    private static extern void CGEventPost(uint tap, IntPtr eventHandle);

    [DllImport(CoreGraphicsLib)]
    private static extern IntPtr CGEventCreateScrollWheelEvent(
        IntPtr source,
        uint units,
        uint wheelCount,
        int wheel1,
        int wheel2);

    [DllImport(CoreGraphicsLib)]
    private static extern IntPtr CGEventCreateKeyboardEvent(IntPtr source, ushort virtualKey, bool keyDown);

    [DllImport(CoreFoundationLib)]
    private static extern void CFRelease(IntPtr cf);

    private const uint kCGHIDEventTap = 0;
    private const uint kCGEventLeftMouseDown = 1;
    private const uint kCGEventLeftMouseUp = 2;
    private const uint kCGEventRightMouseDown = 3;
    private const uint kCGEventRightMouseUp = 4;
    private const uint kCGEventMouseMoved = 5;
    private const uint kCGEventLeftMouseDragged = 6;
    private const uint kCGEventRightMouseDragged = 7;
    private const uint kCGScrollEventUnitPixel = 0;

    private const uint kCGMouseButtonLeft = 0;
    private const uint kCGMouseButtonRight = 1;
    private const uint kCGMouseButtonCenter = 2;

    private bool _leftDown;
    private bool _rightDown;

    public CGPoint GetCursorPosition()
    {
        if (!OperatingSystem.IsMacOS()) return new CGPoint { X = 0, Y = 0 };

        try
        {
            var ev = CGEventCreate(IntPtr.Zero);
            if (ev == IntPtr.Zero) return new CGPoint { X = 0, Y = 0 };
            var loc = CGEventGetLocation(ev);
            CFRelease(ev);
            return loc;
        }
        catch
        {
            return new CGPoint { X = 0, Y = 0 };
        }
    }

    public void MoveMouseRelative(float dx, float dy, float sensitivity = 1.0f)
    {
        if (!OperatingSystem.IsMacOS()) return;

        try
        {
            var pos = GetCursorPosition();
            var newPos = new CGPoint
            {
                X = Math.Max(0, pos.X + (dx * sensitivity)),
                Y = Math.Max(0, pos.Y + (dy * sensitivity))
            };

            CGWarpMouseCursorPosition(newPos);

            uint dragType = _leftDown ? kCGEventLeftMouseDragged : (_rightDown ? kCGEventRightMouseDragged : kCGEventMouseMoved);
            uint button = _leftDown ? kCGMouseButtonLeft : (_rightDown ? kCGMouseButtonRight : kCGMouseButtonLeft);

            var moveEv = CGEventCreateMouseEvent(IntPtr.Zero, dragType, newPos, button);
            if (moveEv != IntPtr.Zero)
            {
                CGEventPost(kCGHIDEventTap, moveEv);
                CFRelease(moveEv);
            }
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Debug("Input", $"Mouse move error: {ex.Message}");
        }
    }

    public void MouseClick(string button = "left", int clicks = 1)
    {
        if (!OperatingSystem.IsMacOS()) return;

        try
        {
            var pos = GetCursorPosition();
            bool isRight = button.Equals("right", StringComparison.OrdinalIgnoreCase);
            uint downType = isRight ? kCGEventRightMouseDown : kCGEventLeftMouseDown;
            uint upType = isRight ? kCGEventRightMouseUp : kCGEventLeftMouseUp;
            uint btn = isRight ? kCGMouseButtonRight : kCGMouseButtonLeft;

            for (int i = 0; i < clicks; i++)
            {
                var down = CGEventCreateMouseEvent(IntPtr.Zero, downType, pos, btn);
                if (down != IntPtr.Zero)
                {
                    CGEventPost(kCGHIDEventTap, down);
                    CFRelease(down);
                }

                Thread.Sleep(15);

                var up = CGEventCreateMouseEvent(IntPtr.Zero, upType, pos, btn);
                if (up != IntPtr.Zero)
                {
                    CGEventPost(kCGHIDEventTap, up);
                    CFRelease(up);
                }

                if (i < clicks - 1) Thread.Sleep(50);
            }
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Debug("Input", $"Mouse click error: {ex.Message}");
        }
    }

    public void SendMouseButton(string button, bool down)
    {
        if (!OperatingSystem.IsMacOS()) return;

        try
        {
            var pos = GetCursorPosition();
            bool isRight = button.Equals("right", StringComparison.OrdinalIgnoreCase);

            if (isRight) _rightDown = down;
            else _leftDown = down;

            uint type = isRight
                ? (down ? kCGEventRightMouseDown : kCGEventRightMouseUp)
                : (down ? kCGEventLeftMouseDown : kCGEventLeftMouseUp);
            uint btn = isRight ? kCGMouseButtonRight : kCGMouseButtonLeft;

            var ev = CGEventCreateMouseEvent(IntPtr.Zero, type, pos, btn);
            if (ev != IntPtr.Zero)
            {
                CGEventPost(kCGHIDEventTap, ev);
                CFRelease(ev);
            }
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Debug("Input", $"Mouse button error: {ex.Message}");
        }
    }

    public void Scroll(float dx, float dy)
    {
        if (!OperatingSystem.IsMacOS()) return;

        try
        {
            // CoreGraphics scroll wheel event: wheel1 = vertical, wheel2 = horizontal
            var scroll = CGEventCreateScrollWheelEvent(
                IntPtr.Zero,
                kCGScrollEventUnitPixel,
                2,
                (int)(dy * 8),
                (int)(dx * 8)
            );
            if (scroll != IntPtr.Zero)
            {
                CGEventPost(kCGHIDEventTap, scroll);
                CFRelease(scroll);
            }
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Debug("Input", $"Scroll error: {ex.Message}");
        }
    }

    public void TypeText(string text)
    {
        if (string.IsNullOrEmpty(text)) return;

        if (OperatingSystem.IsMacOS())
        {
            // Escapes text safely for AppleScript
            var escaped = text.Replace("\\", "\\\\").Replace("\"", "\\\"");
            RunAppleScript($"tell application \"System Events\" to keystroke \"{escaped}\"");
        }
    }

    public void SendSpecialKey(string key, bool down = true)
    {
        if (!OperatingSystem.IsMacOS()) return;

        ushort? code = key.ToLowerInvariant() switch
        {
            "enter" or "return" => 36,
            "tab" => 48,
            "space" => 49,
            "backspace" or "delete" => 51,
            "escape" or "esc" => 53,
            "command" or "cmd" => 55,
            "shift" => 56,
            "option" or "alt" => 58,
            "control" or "ctrl" => 59,
            "left" => 123,
            "right" => 124,
            "down" => 125,
            "up" => 126,
            _ => null
        };

        if (code.HasValue)
        {
            var ev = CGEventCreateKeyboardEvent(IntPtr.Zero, code.Value, down);
            if (ev != IntPtr.Zero)
            {
                CGEventPost(kCGHIDEventTap, ev);
                CFRelease(ev);
            }
        }
    }

    public void SendKeyCombination(List<string> modifiers, string key)
    {
        if (!OperatingSystem.IsMacOS()) return;

        var modList = new List<string>();
        foreach (var m in modifiers)
        {
            var lower = m.ToLowerInvariant();
            if (lower is "command" or "cmd" or "win") modList.Add("command down");
            else if (lower is "control" or "ctrl") modList.Add("control down");
            else if (lower is "alt" or "option") modList.Add("option down");
            else if (lower is "shift") modList.Add("shift down");
        }

        var modStr = modList.Count > 0 ? $" using {{{string.Join(", ", modList)}}}" : "";
        var escapedKey = key.Replace("\"", "\\\"");
        RunAppleScript($"tell application \"System Events\" to keystroke \"{escapedKey}\"{modStr}");
    }

    private static void RunAppleScript(string script)
    {
        try
        {
            using var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "osascript",
                    Arguments = $"-e '{script.Replace("'", "'\\''")}'",
                    UseShellExecute = false,
                    CreateNoWindow = true
                }
            };
            proc.Start();
            proc.WaitForExit(3000);
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Debug("AppleScript", $"Script error: {ex.Message}");
        }
    }
}
