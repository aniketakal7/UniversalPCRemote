using System.Text.Json;
using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Protocol;

namespace UniversalPCRemote.Companion.Security;

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
                return HandlePing(envelope, session);

            default:
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId,
                    envelope.Type,
                    ErrorCodes.UnknownCommand,
                    $"Unhandled auth command: {envelope.Type}"
                ));
        }
    }

    private Task<ResponseEnvelope> HandlePairRequest(CommandEnvelope envelope, DeviceSession session)
    {
        if (envelope.Payload == null)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.InvalidPayload,
                "Missing payload. Required: deviceId, deviceName"
            ));
        }

        try
        {
            var doc = envelope.Payload.Value;
            var deviceId = doc.TryGetProperty("deviceId", out var dIdProp) ? dIdProp.GetString() : null;
            var deviceName = doc.TryGetProperty("deviceName", out var dNameProp) ? dNameProp.GetString() : "Unknown Phone";

            if (string.IsNullOrWhiteSpace(deviceId))
            {
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId,
                    envelope.Type,
                    ErrorCodes.InvalidPayload,
                    "Parameter 'deviceId' is required."
                ));
            }

            var pin = _securityManager.InitiatePairing(deviceId, deviceName ?? "Phone");
            session.DeviceId = deviceId;
            session.DeviceName = deviceName;

            AppLogger.Instance.Info("AuthHandler", $"Pairing requested by '{deviceName}' ({deviceId}).", envelope.RequestId, envelope.Type, session.ConnectionId);

            return Task.FromResult(ResponseEnvelope.CreateSuccess(
                envelope.RequestId,
                envelope.Type,
                new
                {
                    status = "pairing_pending",
                    expiresInSeconds = 120,
                    message = "Please enter the 6-digit PIN displayed on your PC screen."
                }
            ));
        }
        catch (Exception ex)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.ExecutionFailed,
                $"Failed to process pair request: {ex.Message}"
            ));
        }
    }

    private Task<ResponseEnvelope> HandlePairVerify(CommandEnvelope envelope, DeviceSession session)
    {
        if (envelope.Payload == null)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.InvalidPayload,
                "Missing payload. Required: deviceId, pin"
            ));
        }

        try
        {
            var doc = envelope.Payload.Value;
            var deviceId = doc.TryGetProperty("deviceId", out var dIdProp) ? dIdProp.GetString() : session.DeviceId;
            var pin = doc.TryGetProperty("pin", out var pinProp) ? pinProp.GetString() : null;

            if (string.IsNullOrWhiteSpace(deviceId) || string.IsNullOrWhiteSpace(pin))
            {
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId,
                    envelope.Type,
                    ErrorCodes.InvalidPayload,
                    "Parameters 'deviceId' and 'pin' are required."
                ));
            }

            if (_securityManager.VerifyPairing(deviceId, pin, out var authToken, out var errorMessage))
            {
                session.DeviceId = deviceId;
                session.IsAuthenticated = true;

                AppLogger.Instance.Info("AuthHandler", $"Device '{deviceId}' paired successfully.", envelope.RequestId, envelope.Type, session.ConnectionId);

                return Task.FromResult(ResponseEnvelope.CreateSuccess(
                    envelope.RequestId,
                    envelope.Type,
                    new
                    {
                        authenticated = true,
                        deviceId,
                        authToken,
                        pcName = Environment.MachineName
                    }
                ));
            }
            else
            {
                AppLogger.Instance.Warn("AuthHandler", $"Pairing failed for device '{deviceId}': {errorMessage}", envelope.RequestId, envelope.Type, session.ConnectionId);
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId,
                    envelope.Type,
                    ErrorCodes.PairingFailed,
                    errorMessage ?? "Pairing failed."
                ));
            }
        }
        catch (Exception ex)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.ExecutionFailed,
                $"Pairing verification exception: {ex.Message}"
            ));
        }
    }

    private Task<ResponseEnvelope> HandleAuthenticate(CommandEnvelope envelope, DeviceSession session)
    {
        if (envelope.Payload == null)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.InvalidPayload,
                "Missing payload. Required: deviceId, authToken"
            ));
        }

        try
        {
            var doc = envelope.Payload.Value;
            var deviceId = doc.TryGetProperty("deviceId", out var dIdProp) ? dIdProp.GetString() : null;
            var authToken = doc.TryGetProperty("authToken", out var tokProp) ? tokProp.GetString() : null;

            if (string.IsNullOrWhiteSpace(deviceId) || string.IsNullOrWhiteSpace(authToken))
            {
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId,
                    envelope.Type,
                    ErrorCodes.InvalidPayload,
                    "Parameters 'deviceId' and 'authToken' are required."
                ));
            }

            if (_securityManager.AuthenticateDevice(deviceId, authToken, out var record))
            {
                session.DeviceId = deviceId;
                session.DeviceName = record?.DeviceName;
                session.IsAuthenticated = true;

                AppLogger.Instance.Info("AuthHandler", $"Device '{record?.DeviceName}' ({deviceId}) authenticated.", envelope.RequestId, envelope.Type, session.ConnectionId);

                return Task.FromResult(ResponseEnvelope.CreateSuccess(
                    envelope.RequestId,
                    envelope.Type,
                    new
                    {
                        authenticated = true,
                        deviceId,
                        deviceName = record?.DeviceName,
                        pcName = Environment.MachineName
                    }
                ));
            }
            else
            {
                AppLogger.Instance.Warn("AuthHandler", $"Authentication failed for device '{deviceId}'.", envelope.RequestId, envelope.Type, session.ConnectionId);
                return Task.FromResult(ResponseEnvelope.CreateError(
                    envelope.RequestId,
                    envelope.Type,
                    ErrorCodes.Unauthorized,
                    "Invalid device ID or authentication token. Please re-pair your device."
                ));
            }
        }
        catch (Exception ex)
        {
            return Task.FromResult(ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.ExecutionFailed,
                $"Authentication error: {ex.Message}"
            ));
        }
    }

    private Task<ResponseEnvelope> HandlePing(CommandEnvelope envelope, DeviceSession session)
    {
        return Task.FromResult(ResponseEnvelope.CreateSuccess(
            envelope.RequestId,
            CommandTypes.SessionPong,
            new
            {
                timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                authenticated = session.IsAuthenticated
            }
        ));
    }
}
