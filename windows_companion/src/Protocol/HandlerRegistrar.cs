using UniversalPCRemote.Companion.Applications;
using UniversalPCRemote.Companion.Clipboard;
using UniversalPCRemote.Companion.Diagnostics;
using UniversalPCRemote.Companion.Discovery;
using UniversalPCRemote.Companion.Input;
using UniversalPCRemote.Companion.Macros;
using UniversalPCRemote.Companion.Media;
using UniversalPCRemote.Companion.Security;
using UniversalPCRemote.Companion.SystemControl;

namespace UniversalPCRemote.Companion.Protocol;

/// <summary>
/// Single source of truth for registering all command handlers into a registry.
/// Used by both the GUI companion and headless console mode so both always
/// stay in sync without manual duplication.
/// </summary>
public static class HandlerRegistrar
{
    public static void RegisterAll(
        CommandRegistry registry,
        SecurityManager security,
        Func<bool> isRunning,
        int port)
    {
        var authHandler        = new AuthCommandHandler(security);
        var inputHandler       = new InputCommandHandler(NativeInputSimulator.Instance);
        var mediaHandler       = new MediaCommandHandler(MediaController.Instance);
        var systemHandler      = new SystemCommandHandler(SystemController.Instance);
        var clipboardHandler   = new ClipboardCommandHandler(ClipboardController.Instance);
        var remoteHandler      = new RemoteCommandHandler(RemoteCatalog.Instance);
        var macroHandler       = new MacroCommandHandler(MacroEngine.Instance);
        var diagnosticsHandler = new DiagnosticsCommandHandler(isRunning, port);

        // Auth
        registry.Register(CommandTypes.AuthPairRequest,  authHandler);
        registry.Register(CommandTypes.AuthPairVerify,   authHandler);
        registry.Register(CommandTypes.AuthAuthenticate, authHandler);
        registry.Register(CommandTypes.SessionPing,      authHandler);

        // Mouse & Keyboard
        registry.Register(CommandTypes.MouseMove,           inputHandler);
        registry.Register(CommandTypes.MouseClick,          inputHandler);
        registry.Register(CommandTypes.MouseDown,           inputHandler);
        registry.Register(CommandTypes.MouseUp,             inputHandler);
        registry.Register(CommandTypes.MouseScroll,         inputHandler);
        registry.Register(CommandTypes.KeyboardText,        inputHandler);
        registry.Register(CommandTypes.KeyboardKey,         inputHandler);
        registry.Register(CommandTypes.KeyboardCombination, inputHandler);

        // Media
        registry.Register(CommandTypes.MediaPlayPause,   mediaHandler);
        registry.Register(CommandTypes.MediaNext,        mediaHandler);
        registry.Register(CommandTypes.MediaPrevious,    mediaHandler);
        registry.Register(CommandTypes.MediaStop,        mediaHandler);
        registry.Register(CommandTypes.MediaSeekBackward,mediaHandler);
        registry.Register(CommandTypes.MediaSeekForward, mediaHandler);
        registry.Register(CommandTypes.MediaVolumeUp,    mediaHandler);
        registry.Register(CommandTypes.MediaVolumeDown,  mediaHandler);
        registry.Register(CommandTypes.MediaVolumeMute,  mediaHandler);
        registry.Register(CommandTypes.MediaGetStatus,   mediaHandler);

        // System
        registry.Register(CommandTypes.SystemLock,          systemHandler);
        registry.Register(CommandTypes.SystemSleep,         systemHandler);
        registry.Register(CommandTypes.SystemRestart,       systemHandler);
        registry.Register(CommandTypes.SystemShutdown,      systemHandler);
        registry.Register(CommandTypes.SystemCancelShutdown,systemHandler);
        registry.Register(CommandTypes.SystemGetInfo,       systemHandler);

        // Clipboard
        registry.Register(CommandTypes.ClipboardGet, clipboardHandler);
        registry.Register(CommandTypes.ClipboardSet, clipboardHandler);

        // Remotes
        registry.Register(CommandTypes.RemoteList,    remoteHandler);
        registry.Register(CommandTypes.RemoteExecute, remoteHandler);

        // Macros
        registry.Register(CommandTypes.MacroList,    macroHandler);
        registry.Register(CommandTypes.MacroExecute, macroHandler);

        // Diagnostics
        registry.Register(CommandTypes.DiagnosticsStatus, diagnosticsHandler);
    }
}
