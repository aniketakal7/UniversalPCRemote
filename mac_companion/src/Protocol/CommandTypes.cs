namespace UniversalPCRemote.Mac.Protocol;

public static class CommandTypes
{
    // Auth & Session
    public const string AuthPairRequest = "auth.pair_request";
    public const string AuthPairVerify = "auth.pair_verify";
    public const string AuthAuthenticate = "auth.authenticate";
    public const string SessionPing = "session.ping";
    public const string SessionPong = "session.pong";

    // Mouse
    public const string MouseMove = "mouse.move";
    public const string MouseClick = "mouse.click";
    public const string MouseDown = "mouse.down";
    public const string MouseUp = "mouse.up";
    public const string MouseScroll = "mouse.scroll";

    // Keyboard
    public const string KeyboardText = "keyboard.text";
    public const string KeyboardKey = "keyboard.key";
    public const string KeyboardCombination = "keyboard.combination";

    // Media
    public const string MediaPlayPause = "media.play_pause";
    public const string MediaNext = "media.next";
    public const string MediaPrevious = "media.previous";
    public const string MediaStop = "media.stop";
    public const string MediaSeekBackward = "media.seek_backward";
    public const string MediaSeekForward = "media.seek_forward";
    public const string MediaVolumeUp = "media.volume_up";
    public const string MediaVolumeDown = "media.volume_down";
    public const string MediaVolumeMute = "media.volume_mute";
    public const string MediaGetStatus = "media.get_status";

    // System
    public const string SystemLock = "system.lock";
    public const string SystemSleep = "system.sleep";
    public const string SystemRestart = "system.restart";
    public const string SystemShutdown = "system.shutdown";
    public const string SystemCancelShutdown = "system.cancel_shutdown";
    public const string SystemGetInfo = "system.get_info";

    // Clipboard
    public const string ClipboardGet = "clipboard.get";
    public const string ClipboardSet = "clipboard.set";

    // Application Remotes
    public const string RemoteList = "remote.list";
    public const string RemoteExecute = "remote.execute";

    // Macros
    public const string MacroList = "macro.list";
    public const string MacroExecute = "macro.execute";

    // Diagnostics
    public const string DiagnosticsStatus = "diagnostics.status";
}

public static class ErrorCodes
{
    public const string InvalidJson = "INVALID_JSON";
    public const string InvalidEnvelope = "INVALID_ENVELOPE";
    public const string Unauthorized = "UNAUTHORIZED";
    public const string PairingFailed = "PAIRING_FAILED";
    public const string UnknownCommand = "UNKNOWN_COMMAND";
    public const string InvalidPayload = "INVALID_PAYLOAD";
    public const string ExecutionFailed = "EXECUTION_FAILED";
    public const string RateLimited = "RATE_LIMITED";
    public const string ControllerInUse = "CONTROLLER_IN_USE";
}
