using System.Text.Json;
using UniversalPCRemote.Mac.Protocol;
using UniversalPCRemote.Mac.Security;

namespace UniversalPCRemote.Mac.Input;

public class InputCommandHandler : ICommandHandler
{
    private readonly MacNativeInputSimulator _simulator;

    public InputCommandHandler(MacNativeInputSimulator? simulator = null)
    {
        _simulator = simulator ?? MacNativeInputSimulator.Instance;
    }

    public Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.MouseMove:
                return HandleMouseMove(envelope);

            case CommandTypes.MouseClick:
                return HandleMouseClick(envelope);

            case CommandTypes.MouseDown:
                return HandleMouseDown(envelope);

            case CommandTypes.MouseUp:
                return HandleMouseUp(envelope);

            case CommandTypes.MouseScroll:
                return HandleMouseScroll(envelope);

            case CommandTypes.KeyboardText:
                return HandleKeyboardText(envelope);

            case CommandTypes.KeyboardKey:
                return HandleKeyboardKey(envelope);

            case CommandTypes.KeyboardCombination:
                return HandleKeyboardCombination(envelope);

            default:
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.UnknownCommand, $"Unknown input command: {envelope.Type}"
                ));
        }
    }

    private Task<ResponseEnvelope> HandleMouseMove(CommandEnvelope envelope)
    {
        if (envelope.Payload == null)
            return Task.FromResult(ResponseEnvelope.CreateError(envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing payload."));

        var doc = envelope.Payload.Value;
        float dx = doc.TryGetProperty("dx", out var dxP) ? (float)dxP.GetDouble() : 0;
        float dy = doc.TryGetProperty("dy", out var dyP) ? (float)dyP.GetDouble() : 0;
        float sens = doc.TryGetProperty("sensitivity", out var sP) ? (float)sP.GetDouble() : 1.0f;

        _simulator.MoveMouseRelative(dx, dy, sens);
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleMouseClick(CommandEnvelope envelope)
    {
        string button = "left";
        int clicks = 1;
        if (envelope.Payload != null)
        {
            var doc = envelope.Payload.Value;
            if (doc.TryGetProperty("button", out var b)) button = b.GetString() ?? "left";
            if (doc.TryGetProperty("clicks", out var c)) clicks = c.GetInt32();
        }

        _simulator.MouseClick(button, clicks);
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleMouseDown(CommandEnvelope envelope)
    {
        string button = "left";
        if (envelope.Payload != null && envelope.Payload.Value.TryGetProperty("button", out var b))
            button = b.GetString() ?? "left";

        _simulator.SendMouseButton(button, true);
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleMouseUp(CommandEnvelope envelope)
    {
        string button = "left";
        if (envelope.Payload != null && envelope.Payload.Value.TryGetProperty("button", out var b))
            button = b.GetString() ?? "left";

        _simulator.SendMouseButton(button, false);
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleMouseScroll(CommandEnvelope envelope)
    {
        float dx = 0, dy = 0;
        if (envelope.Payload != null)
        {
            var doc = envelope.Payload.Value;
            if (doc.TryGetProperty("dx", out var dxP)) dx = (float)dxP.GetDouble();
            if (doc.TryGetProperty("dy", out var dyP)) dy = (float)dyP.GetDouble();
        }

        _simulator.Scroll(dx, dy);
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleKeyboardText(CommandEnvelope envelope)
    {
        if (envelope.Payload != null && envelope.Payload.Value.TryGetProperty("text", out var t))
        {
            _simulator.TypeText(t.GetString() ?? "");
        }
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleKeyboardKey(CommandEnvelope envelope)
    {
        if (envelope.Payload != null)
        {
            var doc = envelope.Payload.Value;
            var key = doc.TryGetProperty("key", out var k) ? k.GetString() : "";
            var down = !doc.TryGetProperty("down", out var d) || d.GetBoolean();
            if (!string.IsNullOrEmpty(key)) _simulator.SendSpecialKey(key, down);
        }
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleKeyboardCombination(CommandEnvelope envelope)
    {
        if (envelope.Payload != null)
        {
            var doc = envelope.Payload.Value;
            var key = doc.TryGetProperty("key", out var k) ? k.GetString() ?? "" : "";
            var modifiers = new List<string>();
            if (doc.TryGetProperty("modifiers", out var mods) && mods.ValueKind == JsonValueKind.Array)
            {
                foreach (var m in mods.EnumerateArray())
                    if (m.GetString() is string s) modifiers.Add(s);
            }
            _simulator.SendKeyCombination(modifiers, key);
        }
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }
}
