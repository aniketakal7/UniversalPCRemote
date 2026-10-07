using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.Media;

public class MediaCommandHandler : ICommandHandler
{
    private readonly MediaController _controller;

    public MediaCommandHandler(MediaController? controller = null)
    {
        _controller = controller ?? MediaController.Instance;
    }

    public Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.MediaPlayPause:
                _controller.PlayPause();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaNext:
                _controller.NextTrack();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaPrevious:
                _controller.PreviousTrack();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaStop:
                _controller.Stop();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaVolumeUp:
                int upSteps = 1;
                if (envelope.Payload?.TryGetProperty("steps", out var usProp) == true) upSteps = usProp.GetInt32();
                _controller.VolumeUp(upSteps);
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaVolumeDown:
                int downSteps = 1;
                if (envelope.Payload?.TryGetProperty("steps", out var dsProp) == true) downSteps = dsProp.GetInt32();
                _controller.VolumeDown(downSteps);
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaVolumeMute:
                _controller.VolumeMute();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaGetStatus:
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new
                {
                    status = "ready",
                    subsystem = "windows_multimedia"
                }));

            default:
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.UnknownCommand, $"Unknown media command: {envelope.Type}"
                ));
        }
    }
}
