using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.Macros;

public class MacroCommandHandler : ICommandHandler
{
    private readonly MacroEngine _engine;

    public MacroCommandHandler(MacroEngine? engine = null)
    {
        _engine = engine ?? MacroEngine.Instance;
    }

    public async Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.MacroList:
                var macros = _engine.GetAllMacros();
                return ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, macros);

            case CommandTypes.MacroExecute:
                if (envelope.Payload == null)
                {
                    return ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing payload."
                    );
                }

                var macroId = envelope.Payload.Value.TryGetProperty("macroId", out var mProp) ? mProp.GetString() : null;
                if (string.IsNullOrEmpty(macroId))
                {
                    return ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing 'macroId' in payload."
                    );
                }

                var macro = _engine.GetMacro(macroId);
                if (macro == null)
                {
                    return ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, "MACRO_NOT_FOUND", $"Macro '{macroId}' was not found."
                    );
                }

                var success = await _engine.ExecuteMacroAsync(macro, cancellationToken);
                return ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { executed = success, macroId });

            default:
                return ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.UnknownCommand, $"Unknown macro command: {envelope.Type}"
                );
        }
    }
}
