using UniversalPCRemote.Mac.Security;

namespace UniversalPCRemote.Mac.Protocol;

public interface ICommandHandler
{
    Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default);
}
