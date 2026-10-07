using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.Clipboard;

public class ClipboardCommandHandler : ICommandHandler
{
    private readonly ClipboardController _controller;

    public ClipboardCommandHandler(ClipboardController? controller = null)
    {
        _controller = controller ?? ClipboardController.Instance;
    }

    public async Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.ClipboardGet:
                var text = await _controller.GetTextAsync();
                return ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { text });

            case CommandTypes.ClipboardSet:
                if (envelope.Payload?.TryGetProperty("text", out var tProp) != true)
                {
                    return ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing 'text' in payload."
                    );
                }
                var newText = tProp.GetString() ?? "";
                var success = await _controller.SetTextAsync(newText);
                return ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { success });

            default:
                return ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.UnknownCommand, $"Unknown clipboard command: {envelope.Type}"
                );
        }
    }
}
