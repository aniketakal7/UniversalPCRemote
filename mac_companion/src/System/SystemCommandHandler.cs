using UniversalPCRemote.Mac.Protocol;
using UniversalPCRemote.Mac.Security;

namespace UniversalPCRemote.Mac.SystemControl;

public class SystemCommandHandler : ICommandHandler
{
    private readonly MacSystemController _controller;

    public SystemCommandHandler(MacSystemController? controller = null)
    {
        _controller = controller ?? MacSystemController.Instance;
    }

    public Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.SystemLock:
                var locked = _controller.LockMac();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { locked }));

            case CommandTypes.SystemSleep:
                var slept = _controller.SleepMac();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { slept }));

            case CommandTypes.SystemRestart:
                if (envelope.Payload?.TryGetProperty("confirm", out var rConf) != true || !rConf.GetBoolean())
                {
                    return Task.FromResult(ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, "CONFIRMATION_REQUIRED", "Restart requires confirmation."
                    ));
                }
                _controller.RestartMac();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new { scheduled = true }));

            case CommandTypes.SystemShutdown:
                if (envelope.Payload?.TryGetProperty("confirm", out var sConf) != true || !sConf.GetBoolean())
                {
                    return Task.FromResult(ResponseEnvelope.CreateError(
                        envelope.RequestId, envelope.Type, "CONFIRMATION_REQUIRED", "Shutdown requires confirmation."
                    ));
                }
                _controller.ShutdownMac();
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
