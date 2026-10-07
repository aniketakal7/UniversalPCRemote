using System.Collections.Concurrent;
using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.Protocol;

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
        AppLogger.Instance.Debug("CommandRegistry", $"Registered handler for command '{commandType}'");
    }

    public async Task<ResponseEnvelope> RouteAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        if (!envelope.IsValid(out var validationError))
        {
            AppLogger.Instance.Warn("CommandRegistry", $"Invalid envelope: {validationError}", envelope.RequestId, envelope.Type, session.ConnectionId);
            return ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.InvalidEnvelope,
                validationError ?? "Invalid envelope."
            );
        }

        // Authentication enforcement
        if (!session.IsAuthenticated && !_securityManager.IsCommandAllowedUnauthenticated(envelope.Type))
        {
            AppLogger.Instance.Warn("CommandRegistry", $"Unauthorized command attempt: '{envelope.Type}'", envelope.RequestId, envelope.Type, session.ConnectionId);
            return ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.Unauthorized,
                "Unauthorized: Client session is not authenticated. Please pair or authenticate first."
            );
        }

        if (!_handlers.TryGetValue(envelope.Type, out var handler))
        {
            AppLogger.Instance.Warn("CommandRegistry", $"Unknown command type requested: '{envelope.Type}'", envelope.RequestId, envelope.Type, session.ConnectionId);
            return ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.UnknownCommand,
                $"Command type '{envelope.Type}' is not recognized or supported by this server."
            );
        }

        try
        {
            var response = await handler.HandleAsync(envelope, session, cancellationToken);
            return response;
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("CommandRegistry", $"Execution error executing '{envelope.Type}'", ex, envelope.RequestId, envelope.Type, session.ConnectionId);
            return ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.ExecutionFailed,
                $"Internal execution error: {ex.Message}"
            );
        }
    }
}
