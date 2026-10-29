using UniversalPCRemote.Mac.Clipboard;
using UniversalPCRemote.Mac.Diagnostics;
using UniversalPCRemote.Mac.Discovery;
using UniversalPCRemote.Mac.Input;
using UniversalPCRemote.Mac.Logging;
using UniversalPCRemote.Mac.Media;
using UniversalPCRemote.Mac.Protocol;
using UniversalPCRemote.Mac.Security;
using UniversalPCRemote.Mac.Server;
using UniversalPCRemote.Mac.SystemControl;

namespace UniversalPCRemote.Mac;

static class Program
{
    static async Task Main(string[] args)
    {
        Console.Clear();
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine(@"
╔═══════════════════════════════════════════════════════════════════╗
║       Universal PC Remote™ for macOS — Companion Server           ║
║                      by Aniket Akal                               ║
╚═══════════════════════════════════════════════════════════════════╝");
        Console.ResetColor();

        Console.WriteLine();
        Console.WriteLine($"  Mac Name:       {Environment.MachineName}");
        Console.WriteLine($"  OS Version:     macOS ({Environment.OSVersion})");
        Console.WriteLine($"  WebSocket Port: 51234");
        Console.WriteLine($"  Discovery Port: 51235 (UDP)");

        var ips = DiscoveryBeacon.GetLocalIpAddresses();
        Console.WriteLine($"  Mac IP(s):      {(ips.Count > 0 ? string.Join(", ", ips) : "127.0.0.1")}");
        Console.WriteLine();

        var security = SecurityManager.Instance;
        var registry = new CommandRegistry(security);

        // Security events
        security.PairingCodeGenerated += (_, pin, device) =>
        {
            Console.WriteLine();
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("╔═══════════════════════════════════════════════════════════════╗");
            Console.WriteLine($"║   >>>  PAIRING CODE ACTIVE:  {pin}  <<<                      ║");
            Console.WriteLine($"║   Device Name: {device,-46} ║");
            Console.WriteLine("║   Enter this 6-digit PIN on your phone (Expires in 120s)     ║");
            Console.WriteLine("╚═══════════════════════════════════════════════════════════════╝");
            Console.ResetColor();
            Console.WriteLine();
        };

        security.PairingCodeExpired += _ =>
        {
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine("[Security] Pairing code expired or completed.");
            Console.ResetColor();
        };

        security.DevicePaired += record =>
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"[Security] ✓ Device '{record.DeviceName}' successfully paired and trusted!");
            Console.ResetColor();
        };

        // Register handlers
        var authHandler = new AuthCommandHandler(security);
        var inputHandler = new InputCommandHandler(MacNativeInputSimulator.Instance);
        var mediaHandler = new MediaCommandHandler(MacMediaController.Instance);
        var systemHandler = new SystemCommandHandler(MacSystemController.Instance);
        var clipboardHandler = new ClipboardCommandHandler(MacClipboardController.Instance);

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

        var server = new CompanionWebSocketServer(51234, registry);
        var beacon = new DiscoveryBeacon(51234, 51235);
        registry.Register(CommandTypes.DiagnosticsStatus, new DiagnosticsCommandHandler(() => server.IsRunning, server.Port));

        try
        {
            await server.StartAsync();
            beacon.Start();

            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("● Companion server is RUNNING.");
            Console.WriteLine("● Discovery beacon is BROADCASTING.");
            Console.ResetColor();
            Console.WriteLine();
            Console.WriteLine("Ready! Open Universal PC Remote on your Android phone to connect.");
            Console.WriteLine("Press Ctrl+C to stop the companion.");
            Console.WriteLine("───────────────────────────────────────────────────────────────────");
        }
        catch (Exception ex)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"Error starting server: {ex.Message}");
            Console.ResetColor();
            return;
        }

        var tcs = new TaskCompletionSource();
        AppDomain.CurrentDomain.ProcessExit += (_, _) => tcs.TrySetResult();
        Console.CancelKeyPress += (_, e) =>
        {
            e.Cancel = true;
            tcs.TrySetResult();
        };

        await tcs.Task;

        Console.WriteLine("\nShutting down macOS companion...");
        beacon.Stop();
        await server.StopAsync();
        Console.WriteLine("Companion stopped. Goodbye!");
    }
}
