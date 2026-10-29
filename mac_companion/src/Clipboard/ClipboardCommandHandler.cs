using UniversalPCRemote.Mac.Protocol;
using UniversalPCRemote.Mac.Security;

namespace UniversalPCRemote.Mac.Clipboard;

public class ClipboardCommandHandler : ICommandHandler
{
    private readonly MacClipboardController _controller;

    public ClipboardCommandHandler(MacClipboardController? controller = null)
    {
        _controller = controller ?? MacClipboardController.Instance;
    }

    public Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.ClipboardGet:
                var text = _controller.GetText() ?? string.Empty;
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { text }));

            case CommandTypes.ClipboardSet:
                if (envelope.Payload != null && envelope.Payload.Value.TryGetProperty("text", out var tProp))
                {
                    _controller.SetText(tProp.GetString() ?? string.Empty);
                    return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { set = true }));
                }
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing text property in payload."
                ));

            default:
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.UnknownCommand, $"Unknown clipboard command: {envelope.Type}"
                ));
        }
    }
}
