using System.Text.Json;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.Input;

public class InputCommandHandler : ICommandHandler
{
    private readonly NativeInputSimulator _simulator;

    public InputCommandHandler(NativeInputSimulator? simulator = null)
    {
        _simulator = simulator ?? NativeInputSimulator.Instance;
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
                    envelope.RequestId,
                    envelope.Type,
                    ErrorCodes.UnknownCommand,
                    $"Unhandled input command: {envelope.Type}"
                ));
        }
    }

    private Task<ResponseEnvelope> HandleMouseMove(CommandEnvelope envelope)
    {
        if (envelope.Payload == null)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing payload for mouse.move"
            ));
        }

        var doc = envelope.Payload.Value;
        float dx = 0, dy = 0, sensitivity = 1.0f;

        if (doc.TryGetProperty("dx", out var dxProp)) dx = (float)dxProp.GetDouble();
        if (doc.TryGetProperty("dy", out var dyProp)) dy = (float)dyProp.GetDouble();
        if (doc.TryGetProperty("sensitivity", out var sProp)) sensitivity = (float)sProp.GetDouble();

        _simulator.MoveMouseRelative(dx, dy, sensitivity);

        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleMouseClick(CommandEnvelope envelope)
    {
        string button = "left";
        int clicks = 1;

        if (envelope.Payload != null)
        {
            var doc = envelope.Payload.Value;
            if (doc.TryGetProperty("button", out var bProp)) button = bProp.GetString() ?? "left";
            if (doc.TryGetProperty("clicks", out var cProp)) clicks = cProp.GetInt32();
        }

        _simulator.MouseClick(button, clicks);

        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleMouseDown(CommandEnvelope envelope)
    {
        string button = "left";
        if (envelope.Payload != null && envelope.Payload.Value.TryGetProperty("button", out var bProp))
        {
            button = bProp.GetString() ?? "left";
        }

        _simulator.SendMouseButton(button, true);
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleMouseUp(CommandEnvelope envelope)
    {
        string button = "left";
        if (envelope.Payload != null && envelope.Payload.Value.TryGetProperty("button", out var bProp))
        {
            button = bProp.GetString() ?? "left";
        }

        _simulator.SendMouseButton(button, false);
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleMouseScroll(CommandEnvelope envelope)
    {
        float dx = 0, dy = 0;
        if (envelope.Payload != null)
        {
            var doc = envelope.Payload.Value;
            if (doc.TryGetProperty("dx", out var dxProp)) dx = (float)dxProp.GetDouble();
            if (doc.TryGetProperty("dy", out var dyProp)) dy = (float)dyProp.GetDouble();
        }

        _simulator.Scroll(dx, dy);
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleKeyboardText(CommandEnvelope envelope)
    {
        if (envelope.Payload == null || !envelope.Payload.Value.TryGetProperty("text", out var textProp))
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing 'text' in payload"
            ));
        }

        var text = textProp.GetString() ?? "";
        _simulator.SendText(text);

        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleKeyboardKey(CommandEnvelope envelope)
    {
        if (envelope.Payload == null || !envelope.Payload.Value.TryGetProperty("key", out var keyProp))
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing 'key' in payload"
            ));
        }

        var key = keyProp.GetString() ?? "";
        bool down = true;
        if (envelope.Payload.Value.TryGetProperty("down", out var downProp))
        {
            down = downProp.GetBoolean();
        }

        var vk = NativeInputSimulator.ResolveKeyVk(key);
        if (vk != 0)
        {
            _simulator.SendVirtualKey(vk, down);
        }
        else if (key.Length == 1)
        {
            _simulator.SendText(key);
        }

        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }

    private Task<ResponseEnvelope> HandleKeyboardCombination(CommandEnvelope envelope)
    {
        if (envelope.Payload == null || !envelope.Payload.Value.TryGetProperty("key", out var keyProp))
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing 'key' in payload"
            ));
        }

        var key = keyProp.GetString() ?? "";
        var modifiers = new List<string>();

        if (envelope.Payload.Value.TryGetProperty("modifiers", out var modsProp) && modsProp.ValueKind == JsonValueKind.Array)
        {
            foreach (var m in modsProp.EnumerateArray())
            {
                var s = m.GetString();
                if (!string.IsNullOrEmpty(s)) modifiers.Add(s);
            }
        }

        _simulator.SendKeyCombination(modifiers, key);
        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));
    }
}
