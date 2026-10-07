using System.Runtime.InteropServices;
using UniversalPCRemote.Companion.Logging;

namespace UniversalPCRemote.Companion.Input;

public class NativeInputSimulator
{
    private static readonly Lazy<NativeInputSimulator> _instance = new(() => new NativeInputSimulator());
    public static NativeInputSimulator Instance => _instance.Value;

    #region Win32 API Definitions

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, [In] INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion u;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    private const uint INPUT_MOUSE = 0;
    private const uint INPUT_KEYBOARD = 1;

    private const uint MOUSEEVENTF_MOVE = 0x0001;
    private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const uint MOUSEEVENTF_LEFTUP = 0x0004;
    private const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
    private const uint MOUSEEVENTF_RIGHTUP = 0x0010;
    private const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020;
    private const uint MOUSEEVENTF_MIDDLEUP = 0x0040;
    private const uint MOUSEEVENTF_WHEEL = 0x0800;
    private const uint MOUSEEVENTF_HWHEEL = 0x1000;

    private const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const uint KEYEVENTF_UNICODE = 0x0004;

    #endregion

    public (int X, int Y) GetCursorPosition()
    {
        if (GetCursorPos(out var pt))
        {
            return (pt.X, pt.Y);
        }
        return (0, 0);
    }

    public void MoveMouseRelative(float dx, float dy, float sensitivity = 1.0f)
    {
        int moveX = (int)Math.Round(dx * sensitivity);
        int moveY = (int)Math.Round(dy * sensitivity);

        if (moveX == 0 && moveY == 0) return;

        var input = new INPUT
        {
            type = INPUT_MOUSE,
            u = new InputUnion
            {
                mi = new MOUSEINPUT
                {
                    dx = moveX,
                    dy = moveY,
                    dwFlags = MOUSEEVENTF_MOVE,
                    time = 0,
                    dwExtraInfo = IntPtr.Zero
                }
            }
        };

        SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>());
    }

    public void SendMouseButton(string button, bool down)
    {
        uint flag = button.ToLowerInvariant() switch
        {
            "left" => down ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP,
            "right" => down ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP,
            "middle" => down ? MOUSEEVENTF_MIDDLEDOWN : MOUSEEVENTF_MIDDLEUP,
            _ => 0
        };

        if (flag == 0) return;

        var input = new INPUT
        {
            type = INPUT_MOUSE,
            u = new InputUnion
            {
                mi = new MOUSEINPUT
                {
                    dwFlags = flag,
                    time = 0,
                    dwExtraInfo = IntPtr.Zero
                }
            }
        };

        SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>());
    }

    public void MouseClick(string button, int clicks = 1)
    {
        for (int i = 0; i < clicks; i++)
        {
            SendMouseButton(button, true);
            Thread.Sleep(10);
            SendMouseButton(button, false);
            if (i < clicks - 1)
            {
                Thread.Sleep(50);
            }
        }
    }

    public void Scroll(float dx, float dy)
    {
        var inputs = new List<INPUT>();

        if (Math.Abs(dy) > 0.01f)
        {
            // Vertical scroll: 120 per notch standard Win32
            int amount = (int)Math.Round(dy * 120);
            inputs.Add(new INPUT
            {
                type = INPUT_MOUSE,
                u = new InputUnion
                {
                    mi = new MOUSEINPUT
                    {
                        dwFlags = MOUSEEVENTF_WHEEL,
                        mouseData = (uint)amount,
                        time = 0,
                        dwExtraInfo = IntPtr.Zero
                    }
                }
            });
        }

        if (Math.Abs(dx) > 0.01f)
        {
            // Horizontal scroll
            int amount = (int)Math.Round(dx * 120);
            inputs.Add(new INPUT
            {
                type = INPUT_MOUSE,
                u = new InputUnion
                {
                    mi = new MOUSEINPUT
                    {
                        dwFlags = MOUSEEVENTF_HWHEEL,
                        mouseData = (uint)amount,
                        time = 0,
                        dwExtraInfo = IntPtr.Zero
                    }
                }
            });
        }

        if (inputs.Count > 0)
        {
            SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf<INPUT>());
        }
    }

    public void SendText(string text)
    {
        if (string.IsNullOrEmpty(text)) return;

        var inputs = new List<INPUT>();

        foreach (char c in text)
        {
            if (c == '\r') continue; // Handle newlines via '\n'

            // Unicode key down
            inputs.Add(new INPUT
            {
                type = INPUT_KEYBOARD,
                u = new InputUnion
                {
                    ki = new KEYBDINPUT
                    {
                        wVk = 0,
                        wScan = (ushort)c,
                        dwFlags = KEYEVENTF_UNICODE,
                        time = 0,
                        dwExtraInfo = IntPtr.Zero
                    }
                }
            });

            // Unicode key up
            inputs.Add(new INPUT
            {
                type = INPUT_KEYBOARD,
                u = new InputUnion
                {
                    ki = new KEYBDINPUT
                    {
                        wVk = 0,
                        wScan = (ushort)c,
                        dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                        time = 0,
                        dwExtraInfo = IntPtr.Zero
                    }
                }
            });
        }

        SendInput((uint)inputs.Count, inputs.ToArray(), Marshal.SizeOf<INPUT>());
    }

    public void SendVirtualKey(ushort vk, bool down)
    {
        uint flags = 0;
        if (!down) flags |= KEYEVENTF_KEYUP;

        // Certain keys require EXTENDEDKEY flag
        if (vk is 0x21 or 0x22 or 0x23 or 0x24 or 0x25 or 0x26 or 0x27 or 0x28 or 0x2D or 0x2E or 0x5B or 0x5C)
        {
            flags |= KEYEVENTF_EXTENDEDKEY;
        }

        var input = new INPUT
        {
            type = INPUT_KEYBOARD,
            u = new InputUnion
            {
                ki = new KEYBDINPUT
                {
                    wVk = vk,
                    wScan = 0,
                    dwFlags = flags,
                    time = 0,
                    dwExtraInfo = IntPtr.Zero
                }
            }
        };

        SendInput(1, new[] { input }, Marshal.SizeOf<INPUT>());
    }

    public void SendKeyCombination(IEnumerable<string> modifiers, string key)
    {
        var modVks = modifiers.Select(ResolveModifierVk).Where(vk => vk != 0).ToList();
        var mainVk = ResolveKeyVk(key);

        // Press modifiers down
        foreach (var m in modVks)
        {
            SendVirtualKey(m, true);
        }

        Thread.Sleep(5);

        // Press main key down and up
        if (mainVk != 0)
        {
            SendVirtualKey(mainVk, true);
            Thread.Sleep(10);
            SendVirtualKey(mainVk, false);
        }
        else if (key.Length == 1)
        {
            SendText(key);
        }

        Thread.Sleep(5);

        // Release modifiers in reverse order
        for (int i = modVks.Count - 1; i >= 0; i--)
        {
            SendVirtualKey(modVks[i], false);
        }
    }

    public static ushort ResolveModifierVk(string modifier)
    {
        return modifier.ToLowerInvariant() switch
        {
            "ctrl" or "control" => 0x11, // VK_CONTROL
            "alt" => 0x12,              // VK_MENU
            "shift" => 0x10,            // VK_SHIFT
            "win" or "windows" or "meta" => 0x5B, // VK_LWIN
            _ => 0
        };
    }

    public static ushort ResolveKeyVk(string key)
    {
        var k = key.ToUpperInvariant();
        if (k.Length == 1 && k[0] is >= 'A' and <= 'Z' or >= '0' and <= '9')
        {
            return (ushort)k[0];
        }

        return k switch
        {
            "ENTER" or "RETURN" => 0x0D,
            "BACKSPACE" or "BACK" => 0x08,
            "TAB" => 0x09,
            "ESCAPE" or "ESC" => 0x1B,
            "SPACE" => 0x20,
            "DELETE" or "DEL" => 0x2E,
            "INSERT" or "INS" => 0x2D,
            "HOME" => 0x24,
            "END" => 0x23,
            "PAGEUP" or "PGUP" => 0x21,
            "PAGEDOWN" or "PGDN" => 0x22,
            "UP" or "ARROWUP" => 0x26,
            "DOWN" or "ARROWDOWN" => 0x28,
            "LEFT" or "ARROWLEFT" => 0x25,
            "RIGHT" or "ARROWRIGHT" => 0x27,
            "F1" => 0x70,
            "F2" => 0x71,
            "F3" => 0x72,
            "F4" => 0x73,
            "F5" => 0x74,
            "F6" => 0x75,
            "F7" => 0x76,
            "F8" => 0x77,
            "F9" => 0x78,
            "F10" => 0x79,
            "F11" => 0x7A,
            "F12" => 0x7B,
            _ => 0
        };
    }
}
