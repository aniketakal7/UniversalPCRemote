using UniversalPCRemote.Companion.Applications;
using UniversalPCRemote.Companion.Clipboard;
using UniversalPCRemote.Companion.Diagnostics;
using UniversalPCRemote.Companion.Discovery;
using UniversalPCRemote.Companion.Input;
using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Macros;
using UniversalPCRemote.Companion.Media;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;
using UniversalPCRemote.Companion.Server;
using UniversalPCRemote.Companion.SystemControl;

namespace UniversalPCRemote.Companion;

static class Program
{
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
    private static extern IntPtr FindWindow(string? lpClassName, string lpWindowName);

    private const int SW_RESTORE = 9;

    [STAThread]
    static async Task Main(string[] args)
    {
        AppDomain.CurrentDomain.UnhandledException += (s, e) =>
        {
            try { AppLogger.Instance.Error("Fatal", $"Unhandled domain exception: {e.ExceptionObject}"); } catch { }
        };
        Application.ThreadException += (s, e) =>
        {
            try { AppLogger.Instance.Error("Fatal", $"Unhandled thread exception: {e.Exception.Message}", e.Exception); } catch { }
        };

        const string MutexName = "Local\\UniversalPCRemote_SingleInstance_Mutex";
        using var mutex = new Mutex(true, MutexName, out bool createdNew);
        if (!createdNew)
        {
            // Another instance is already running; bring it to foreground
            var hWnd = FindWindow(null, "Universal PC Remote™ by Aniket Akal — Companion Server");
            if (hWnd != IntPtr.Zero)
            {
                ShowWindow(hWnd, SW_RESTORE);
                SetForegroundWindow(hWnd);
            }
            return;
        }

        if (args.Contains("--headless") || args.Contains("--console"))
        {
            await RunHeadlessAsync();
            return;
        }

        ApplicationConfiguration.Initialize();
        Application.Run(new UI.MainForm());
    }

    private static async Task RunHeadlessAsync()
    {
        Console.WriteLine("=========================================================");
        Console.WriteLine("  Universal PC Remote — Companion Service");
        Console.WriteLine("=========================================================");

        var security = SecurityManager.Instance;
        var registry = new CommandRegistry(security);

        security.PairingCodeGenerated += (_, pin, device) =>
        {
            Console.WriteLine();
            Console.WriteLine("*********************************************************");
            Console.WriteLine($"  >>> PAIRING CODE ACTIVE: {pin} <<<");
            Console.WriteLine($"  Device Name: {device}");
            Console.WriteLine("  Enter this 6-digit code on your Android phone.");
            Console.WriteLine("*********************************************************");
            Console.WriteLine();
        };

        var authHandler = new AuthCommandHandler(security);
        var inputHandler = new InputCommandHandler(NativeInputSimulator.Instance);
        var mediaHandler = new MediaCommandHandler(MediaController.Instance);
        var systemHandler = new SystemCommandHandler(SystemController.Instance);
        var clipboardHandler = new ClipboardCommandHandler(ClipboardController.Instance);
        var remoteHandler = new RemoteCommandHandler(RemoteCatalog.Instance);
        var macroHandler = new MacroCommandHandler(MacroEngine.Instance);

        registry.Register(CommandTypes.AuthPairRequest, authHandler);
        registry.Register(CommandTypes.AuthPairVerify, authHandler);
        registry.Register(CommandTypes.AuthAuthenticate, authHandler);
        registry.Register(CommandTypes.SessionPing, authHandler);

        registry.Register(CommandTypes.MouseMove, inputHandler);
        registry.Register(CommandTypes.MouseClick, inputHandler);
        registry.Register(CommandTypes.MouseDown, inputHandler);
        registry.Register(CommandTypes.MouseUp, inputHandler);
        registry.Register(CommandTypes.MouseScroll, inputHandler);
        registry.Register(CommandTypes.KeyboardText, inputHandler);
        registry.Register(CommandTypes.KeyboardKey, inputHandler);
        registry.Register(CommandTypes.KeyboardCombination, inputHandler);

        registry.Register(CommandTypes.MediaPlayPause, mediaHandler);
        registry.Register(CommandTypes.MediaNext, mediaHandler);
        registry.Register(CommandTypes.MediaPrevious, mediaHandler);
        registry.Register(CommandTypes.MediaStop, mediaHandler);
        registry.Register(CommandTypes.MediaSeekBackward, mediaHandler);
        registry.Register(CommandTypes.MediaSeekForward, mediaHandler);
        registry.Register(CommandTypes.MediaVolumeUp, mediaHandler);
        registry.Register(CommandTypes.MediaVolumeDown, mediaHandler);
        registry.Register(CommandTypes.MediaVolumeMute, mediaHandler);
        registry.Register(CommandTypes.MediaGetStatus, mediaHandler);

        registry.Register(CommandTypes.SystemLock, systemHandler);
        registry.Register(CommandTypes.SystemSleep, systemHandler);
        registry.Register(CommandTypes.SystemRestart, systemHandler);
        registry.Register(CommandTypes.SystemShutdown, systemHandler);
        registry.Register(CommandTypes.SystemCancelShutdown, systemHandler);
        registry.Register(CommandTypes.SystemGetInfo, systemHandler);

        registry.Register(CommandTypes.ClipboardGet, clipboardHandler);
        registry.Register(CommandTypes.ClipboardSet, clipboardHandler);

        registry.Register(CommandTypes.RemoteList, remoteHandler);
        registry.Register(CommandTypes.RemoteExecute, remoteHandler);

        registry.Register(CommandTypes.MacroList, macroHandler);
        registry.Register(CommandTypes.MacroExecute, macroHandler);

        var server = new CompanionWebSocketServer(51234, registry);
        var beacon = new DiscoveryBeacon(51234, 51235);
        var diagHandler = new DiagnosticsCommandHandler(() => server.IsRunning, server.Port);
        registry.Register(CommandTypes.DiagnosticsStatus, diagHandler);

        await server.StartAsync();
        beacon.Start();

        var localIps = DiscoveryBeacon.GetLocalIpAddresses();
        Console.WriteLine($"Server active on WebSocket port 51234 and UDP 51235.");
        Console.WriteLine($"PC Name: {Environment.MachineName}");
        Console.WriteLine($"Available IP(s): {string.Join(", ", localIps)}");
        Console.WriteLine("Ready for incoming Android connection...");

        var tcs = new TaskCompletionSource();
        AppDomain.CurrentDomain.ProcessExit += (_, _) => tcs.TrySetResult();
        Console.CancelKeyPress += (_, e) =>
        {
            e.Cancel = true;
            tcs.TrySetResult();
        };

        await tcs.Task;

        beacon.Stop();
        await server.StopAsync();
    }
}
