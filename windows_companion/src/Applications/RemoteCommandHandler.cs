using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.Applications;

public class RemoteCommandHandler : ICommandHandler
{
    private readonly RemoteCatalog _catalog;

    public RemoteCommandHandler(RemoteCatalog? catalog = null)
    {
        _catalog = catalog ?? RemoteCatalog.Instance;
    }

    public Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.RemoteList:
                var remotes = _catalog.GetAllRemotes();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, remotes));

            case CommandTypes.RemoteExecute:
                if (envelope.Payload == null)
                {
                    return Task.FromResult(ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing payload."
                    ));
                }

                var doc = envelope.Payload.Value;
                var remoteId = doc.TryGetProperty("remoteId", out var rProp) ? rProp.GetString() : null;
                var actionId = doc.TryGetProperty("actionId", out var aProp) ? aProp.GetString() : null;

                if (string.IsNullOrEmpty(remoteId) || string.IsNullOrEmpty(actionId))
                {
                    return Task.FromResult(ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing 'remoteId' or 'actionId'."
                    ));
                }

                var remote = _catalog.GetRemote(remoteId);
                if (remote == null)
                {
                    return Task.FromResult(ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, "REMOTE_NOT_FOUND", $"Remote '{remoteId}' was not found."
                    ));
                }

                var action = remote.Actions.FirstOrDefault(a => string.Equals(a.Id, actionId, StringComparison.OrdinalIgnoreCase));
                if (action == null)
                {
                    return Task.FromResult(ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, "ACTION_NOT_FOUND", $"Action '{actionId}' was not found on remote '{remoteId}'."
                    ));
                }

                if (_catalog.ExecuteAction(action, out var error))
                {
                    return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { executed = true, actionId }));
                }
                else
                {
                    return Task.FromResult(ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, ErrorCodes.ExecutionFailed, error ?? "Execution failed."
                    ));
                }

            default:
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.UnknownCommand, $"Unknown remote command: {envelope.Type}"
                ));
        }
    }
}
