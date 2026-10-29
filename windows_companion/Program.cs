using UniversalPCRemote.Companion.Discovery;
using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;
using UniversalPCRemote.Companion.Server;

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

        var server = new CompanionWebSocketServer(51234, registry);
        var beacon = new DiscoveryBeacon(51234, 51235);

        // Single registration point — shared with the GUI companion via HandlerRegistrar
        HandlerRegistrar.RegisterAll(registry, security, () => server.IsRunning, server.Port);

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
