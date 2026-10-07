using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.Protocol;

public interface ICommandHandler
{
    Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default);
}
