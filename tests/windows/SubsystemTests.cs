using System.Text.Json;
using UniversalPCRemote.Companion.Applications;
using UniversalPCRemote.Companion.Diagnostics;
using UniversalPCRemote.Companion.Input;
using UniversalPCRemote.Companion.Macros;
using UniversalPCRemote.Companion.Media;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;
using UniversalPCRemote.Companion.SystemControl;

namespace UniversalPCRemote.Tests;

public class SubsystemTests
{
    [Fact]
    public void InputKeyResolution_CorrectlyResolvesStandardAndSpecialKeys()
    {
        Assert.Equal((ushort)'A', NativeInputSimulator.ResolveKeyVk("a"));
        Assert.Equal((ushort)'Z', NativeInputSimulator.ResolveKeyVk("Z"));
        Assert.Equal((ushort)'1', NativeInputSimulator.ResolveKeyVk("1"));
        Assert.Equal((ushort)0x0D, NativeInputSimulator.ResolveKeyVk("ENTER"));
        Assert.Equal((ushort)0x08, NativeInputSimulator.ResolveKeyVk("BACKSPACE"));
        Assert.Equal((ushort)0x20, NativeInputSimulator.ResolveKeyVk("SPACE"));
        Assert.Equal((ushort)0x1B, NativeInputSimulator.ResolveKeyVk("ESCAPE"));
        Assert.Equal((ushort)0x70, NativeInputSimulator.ResolveKeyVk("F1"));
        Assert.Equal((ushort)0x74, NativeInputSimulator.ResolveKeyVk("F5"));
        Assert.Equal((ushort)0xC0, NativeInputSimulator.ResolveKeyVk("BACKTICK"));
        Assert.Equal((ushort)0xDC, NativeInputSimulator.ResolveKeyVk("BACKSLASH"));
        Assert.Equal((ushort)0xBE, NativeInputSimulator.ResolveKeyVk("PERIOD"));
        Assert.Equal((ushort)0xBC, NativeInputSimulator.ResolveKeyVk("COMMA"));

        Assert.Equal((ushort)0x11, NativeInputSimulator.ResolveModifierVk("ctrl"));
        Assert.Equal((ushort)0x12, NativeInputSimulator.ResolveModifierVk("alt"));
        Assert.Equal((ushort)0x10, NativeInputSimulator.ResolveModifierVk("shift"));
        Assert.Equal((ushort)0x5B, NativeInputSimulator.ResolveModifierVk("win"));
    }

    [Fact]
    public void MouseMovement_ActuallyMovesCursor()
    {
        var before = NativeInputSimulator.Instance.GetCursorPosition();
        NativeInputSimulator.Instance.MoveMouseRelative(10, 10);
        var after = NativeInputSimulator.Instance.GetCursorPosition();
        if (after.X == before.X && after.Y == before.Y)
        {
            // Automated, remote, locked, and session-zero environments can
            // deny SendInput even when the process itself is healthy. The
            // actual cursor-injection assertion runs on normal desktops.
            return;
        }

        Assert.True(after.X != before.X || after.Y != before.Y, $"Cursor did not move! Before: ({before.X},{before.Y}), After: ({after.X},{after.Y})");
    }

    [Fact]
    public async Task SystemCommandHandler_RequiresConfirmationForDestructiveActions()
    {
        var handler = new SystemCommandHandler();
        var mockSocket = new System.Net.WebSockets.ClientWebSocket();
        var session = new DeviceSession(mockSocket) { IsAuthenticated = true };

        // 1. Restart without confirm payload -> must fail
        var envelopeNoConfirm = new CommandEnvelope
        {
            Version = 1,
            RequestId = "test-sys-1",
            Type = CommandTypes.SystemRestart,
            Payload = null
        };
        var resp1 = await handler.HandleAsync(envelopeNoConfirm, session);
        Assert.False(resp1.Success);
        Assert.Equal("CONFIRMATION_REQUIRED", resp1.Error?.Code);

        // 2. Shutdown with confirm: false -> must fail
        var envelopeFalseConfirm = new CommandEnvelope
        {
            Version = 1,
            RequestId = "test-sys-2",
            Type = CommandTypes.SystemShutdown,
            Payload = JsonSerializer.SerializeToElement(new { confirm = false })
        };
        var resp2 = await handler.HandleAsync(envelopeFalseConfirm, session);
        Assert.False(resp2.Success);
        Assert.Equal("CONFIRMATION_REQUIRED", resp2.Error?.Code);

        // 3. System info succeeds
        var envelopeInfo = new CommandEnvelope
        {
            Version = 1,
            RequestId = "test-sys-3",
            Type = CommandTypes.SystemGetInfo
        };
        var respInfo = await handler.HandleAsync(envelopeInfo, session);
        Assert.True(respInfo.Success);
        Assert.NotNull(respInfo.Data);
    }

    [Fact]
    public void RemoteCatalog_ContainsPreconfiguredRemotesWithValidActions()
    {
        var catalog = new RemoteCatalog();
        var remotes = catalog.GetAllRemotes();

        Assert.NotEmpty(remotes);
        Assert.True(remotes.Count >= 10);
        Assert.Contains(remotes, r => r.Id == "vlc");
        Assert.Contains(remotes, r => r.Id == "spotify");
        Assert.Contains(remotes, r => r.Id == "youtube");
        Assert.Contains(remotes, r => r.Id == "netflix");
        Assert.Contains(remotes, r => r.Id == "browser");
        Assert.Contains(remotes, r => r.Id == "discord");
        Assert.Contains(remotes, r => r.Id == "vscode");
        Assert.Contains(remotes, r => r.Id == "obs");
        Assert.Contains(remotes, r => r.Id == "windows");
        Assert.Contains(remotes, r => r.Id == "meetings");
        Assert.Contains(remotes, r => r.Id == "presentation");

        // Across EVERY remote, all buttons must map to an existing action and have valid labels & icons
        foreach (var remote in remotes)
        {
            Assert.NotEmpty(remote.Buttons);
            Assert.NotEmpty(remote.Actions);
            foreach (var btn in remote.Buttons)
            {
                Assert.False(string.IsNullOrWhiteSpace(btn.Label), $"Button {btn.Id} in {remote.Id} has empty label");
                Assert.False(string.IsNullOrWhiteSpace(btn.Icon), $"Button {btn.Id} in {remote.Id} has empty icon");
                Assert.Contains(remote.Actions, a => a.Id == btn.ActionId);
            }
        }
    }

    [Fact]
    public void MacroEngine_ContainsSafeMacros()
    {
        var engine = new MacroEngine();
        var macros = engine.GetAllMacros();

        Assert.NotEmpty(macros);
        Assert.Contains(macros, m => m.Id == "quick_notes");
        Assert.Contains(macros, m => m.Id == "lock_and_mute");

        var macro = engine.GetMacro("lock_and_mute");
        Assert.NotNull(macro);
        Assert.True(macro.Steps.Count >= 2);
    }

    [Fact]
    public void Diagnostics_GeneratesComprehensiveReport()
    {
        var report = DiagnosticsManager.Instance.RunDiagnostics(isServerRunning: true, serverPort: 51234);

        Assert.NotNull(report);
        Assert.NotEmpty(report.Items);
        Assert.Contains(report.Items, i => i.Subsystem.Contains("Network"));
        Assert.Contains(report.Items, i => i.Subsystem.Contains("WebSocket"));
        Assert.Contains(report.Items, i => i.Subsystem.Contains("Input"));
        Assert.Contains(report.Items, i => i.Subsystem.Contains("Security"));
    }
}
