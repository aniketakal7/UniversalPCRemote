using System.Collections.Concurrent;
using UniversalPCRemote.Mac.Logging;
using UniversalPCRemote.Mac.Security;

namespace UniversalPCRemote.Mac.Protocol;

public class CommandRegistry
{
    private readonly ConcurrentDictionary<string, ICommandHandler> _handlers = new(StringComparer.OrdinalIgnoreCase);
    private readonly SecurityManager _securityManager;

    public CommandRegistry(SecurityManager? securityManager = null)
    {
        _securityManager = securityManager ?? SecurityManager.Instance;
    }

    public void Register(string commandType, ICommandHandler handler)
    {
        _handlers[commandType] = handler;
    }

    public async Task<ResponseEnvelope> RouteAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        if (!envelope.IsValid(out var validationError))
        {
            return ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.InvalidEnvelope,
                validationError ?? "Invalid envelope."
            );
        }

        if (!session.IsAuthenticated && !_securityManager.IsCommandAllowedUnauthenticated(envelope.Type))
        {
            return ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.Unauthorized,
                "Unauthorized: Client session is not authenticated."
            );
        }

        if (!_handlers.TryGetValue(envelope.Type, out var handler))
        {
            return ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.UnknownCommand,
                $"Command '{envelope.Type}' is not supported on this macOS companion."
            );
        }

        try
        {
            return await handler.HandleAsync(envelope, session, cancellationToken);
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("CommandRegistry", $"Error executing '{envelope.Type}'", ex);
            return ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.ExecutionFailed,
                ex.Message
            );
        }
    }
}
