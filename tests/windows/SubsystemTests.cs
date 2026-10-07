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

        Assert.Equal((ushort)0x11, NativeInputSimulator.ResolveModifierVk("ctrl"));
        Assert.Equal((ushort)0x12, NativeInputSimulator.ResolveModifierVk("alt"));
        Assert.Equal((ushort)0x10, NativeInputSimulator.ResolveModifierVk("shift"));
        Assert.Equal((ushort)0x5B, NativeInputSimulator.ResolveModifierVk("win"));
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
        Assert.Contains(remotes, r => r.Id == "vlc");
        Assert.Contains(remotes, r => r.Id == "browser");
        Assert.Contains(remotes, r => r.Id == "presentation");

        var vlc = catalog.GetRemote("vlc");
        Assert.NotNull(vlc);
        Assert.NotEmpty(vlc.Buttons);
        Assert.NotEmpty(vlc.Actions);

        // All buttons must map to an existing action
        foreach (var btn in vlc.Buttons)
        {
            Assert.Contains(vlc.Actions, a => a.Id == btn.ActionId);
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
