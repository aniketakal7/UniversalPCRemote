using UniversalPCRemote.Mac.Protocol;
using UniversalPCRemote.Mac.Security;

namespace UniversalPCRemote.Mac.Media;

public class MediaCommandHandler : ICommandHandler
{
    private readonly MacMediaController _controller;

    public MediaCommandHandler(MacMediaController? controller = null)
    {
        _controller = controller ?? MacMediaController.Instance;
    }

    public Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.MediaPlayPause:
                _controller.PlayPause();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaNext:
                _controller.Next();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaPrevious:
                _controller.Previous();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaStop:
                _controller.Stop();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaVolumeUp:
                _controller.VolumeUp();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaVolumeDown:
                _controller.VolumeDown();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaVolumeMute:
                _controller.VolumeMute();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type));

            case CommandTypes.MediaGetStatus:
                var status = _controller.GetStatus();
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, status));

            default:
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.UnknownCommand, $"Unknown media command: {envelope.Type}"
                ));
        }
    }
}
