using System.Text.Json;
using UniversalPCRemote.Mac.Protocol;

namespace UniversalPCRemote.Mac.Security;

public class AuthCommandHandler : ICommandHandler
{
    private readonly SecurityManager _securityManager;

    public AuthCommandHandler(SecurityManager? securityManager = null)
    {
        _securityManager = securityManager ?? SecurityManager.Instance;
    }

    public Task<ResponseEnvelope> HandleAsync(CommandEnvelope envelope, DeviceSession session, CancellationToken cancellationToken = default)
    {
        switch (envelope.Type)
        {
            case CommandTypes.AuthPairRequest:
                return HandlePairRequest(envelope, session);

            case CommandTypes.AuthPairVerify:
                return HandlePairVerify(envelope, session);

            case CommandTypes.AuthAuthenticate:
                return HandleAuthenticate(envelope, session);

            case CommandTypes.SessionPing:
                return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, CommandTypes.SessionPong, new
                {
                    timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                    machine = Environment.MachineName,
                    os = "macOS"
                }));

            default:
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId, envelope.Type, ErrorCodes.UnknownCommand, $"Unknown auth command: {envelope.Type}"
                ));
        }
    }

    private Task<ResponseEnvelope> HandlePairRequest(CommandEnvelope envelope, DeviceSession session)
    {
        if (envelope.Payload == null)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing payload for pair request."
            ));
        }

        var doc = envelope.Payload.Value;
        var deviceId = doc.TryGetProperty("deviceId", out var did) ? did.GetString() : null;
        var deviceName = doc.TryGetProperty("deviceName", out var dname) ? dname.GetString() : "Unknown Device";

        if (string.IsNullOrWhiteSpace(deviceId))
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "deviceId is required."
            ));
        }

        session.DeviceId = deviceId;
        session.DeviceName = deviceName;

        var pin = _securityManager.InitiatePairing(deviceId, deviceName ?? "Device");

        return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new
        {
            pinRequired = true,
            expiresInSeconds = 120,
            deviceId,
            deviceName
        }));
    }

    private Task<ResponseEnvelope> HandlePairVerify(CommandEnvelope envelope, DeviceSession session)
    {
        if (envelope.Payload == null)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing payload for pair verification."
            ));
        }

        var doc = envelope.Payload.Value;
        var deviceId = doc.TryGetProperty("deviceId", out var did) ? did.GetString() : session.DeviceId;
        var pin = doc.TryGetProperty("pin", out var p) ? p.GetString() : null;

        if (string.IsNullOrWhiteSpace(deviceId) || string.IsNullOrWhiteSpace(pin))
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "deviceId and pin are required."
            ));
        }

        if (_securityManager.VerifyPairing(deviceId, pin, out var token, out var error))
        {
            session.IsAuthenticated = true;
            session.DeviceId = deviceId;

            return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new
            {
                authenticated = true,
                authToken = token,
                deviceId
            }));
        }

        return Task.FromResult(ResponseEnvelope.CreateError(
            envelope.RequestId, envelope.Type, ErrorCodes.PairingFailed, error ?? "Pairing failed."
        ));
    }

    private Task<ResponseEnvelope> HandleAuthenticate(CommandEnvelope envelope, DeviceSession session)
    {
        if (envelope.Payload == null)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "Missing payload for authentication."
            ));
        }

        var doc = envelope.Payload.Value;
        var deviceId = doc.TryGetProperty("deviceId", out var did) ? did.GetString() : null;
        var authToken = doc.TryGetProperty("authToken", out var tok) ? tok.GetString() : null;

        if (string.IsNullOrWhiteSpace(deviceId) || string.IsNullOrWhiteSpace(authToken))
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId, envelope.Type, ErrorCodes.InvalidPayload, "deviceId and authToken are required."
            ));
        }

        if (_securityManager.AuthenticateDevice(deviceId, authToken, out var record))
        {
            session.IsAuthenticated = true;
            session.DeviceId = deviceId;
            session.DeviceName = record?.DeviceName;

            return Task.FromResult(ResponseEnvelope.CreateSuccess(envelope.RequestId, envelope.Type, new
            {
                authenticated = true,
                deviceName = record?.DeviceName
            }));
        }

        return Task.FromResult(ResponseEnvelope.CreateError(
            envelope.RequestId, envelope.Type, ErrorCodes.Unauthorized, "Authentication token is invalid or expired."
        ));
    }
}
