using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.SystemControl;

public class SystemCommandHandler : ICommandHandler
{
    private readonly SystemController _controller;

    public SystemCommandHandler(SystemController? controller = null)
    {
        _controller = controller ?? SystemController.Instance;
    }

    public Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.SystemLock:
                var locked = _controller.LockPC();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { locked }));

            case CommandTypes.SystemSleep:
                var slept = _controller.SleepPC();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { slept }));

            case CommandTypes.SystemRestart:
                if (envelope.Payload?.TryGetProperty("confirm", out var rConf) != true || !rConf.GetBoolean())
                {
                    return Task.FromResult(ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, "CONFIRMATION_REQUIRED", "Restart requires explicit confirmation."
                    ));
                }
                _controller.RestartPC();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { scheduled = true }));

            case CommandTypes.SystemShutdown:
                if (envelope.Payload?.TryGetProperty("confirm", out var sConf) != true || !sConf.GetBoolean())
                {
                    return Task.FromResult(ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, "CONFIRMATION_REQUIRED", "Shutdown requires explicit confirmation."
                    ));
                }
                _controller.ShutdownPC();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { scheduled = true }));

            case CommandTypes.SystemCancelShutdown:
                _controller.CancelShutdown();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { cancelled = true }));

            case CommandTypes.SystemGetInfo:
                var info = _controller.GetSystemInfo();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, info));

            default:
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.UnknownCommand, $"Unknown system command: {envelope.Type}"
                ));
        }
    }
}
