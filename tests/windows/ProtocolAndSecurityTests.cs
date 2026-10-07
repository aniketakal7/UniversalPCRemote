using System.Text.Json;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Tests;

public class ProtocolAndSecurityTests
{
    [Fact]
    public void ValidEnvelope_ShouldPassValidation()
    {
        var envelope = new CommandEnvelope
        {
            Version = 1,
            RequestId = Guid.NewGuid().ToString("N"),
            Type = "mouse.move",
            Timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
            Payload = JsonSerializer.SerializeToElement(new { dx = 10, dy = 20 })
        };

        var isValid = envelope.IsValid(out var error);

        Assert.True(isValid);
        Assert.Null(error);
    }

    [Fact]
    public void UnsupportedVersion_ShouldFailValidation()
    {
        var envelope = new CommandEnvelope
        {
            Version = 2,
            RequestId = Guid.NewGuid().ToString("N"),
            Type = "mouse.move"
        };

        var isValid = envelope.IsValid(out var error);

        Assert.False(isValid);
        Assert.Contains("Unsupported protocol version", error);
    }

    [Fact]
    public void MissingRequestId_ShouldFailValidation()
    {
        var envelope = new CommandEnvelope
        {
            Version = 1,
            RequestId = "",
            Type = "mouse.move"
        };

        var isValid = envelope.IsValid(out var error);

        Assert.False(isValid);
        Assert.Contains("requestId", error);
    }

    [Fact]
    public async Task UnauthenticatedSession_ShouldRejectProtectedCommand()
    {
        var registry = new CommandRegistry();
        var mockSocket = new System.Net.WebSockets.ClientWebSocket();
        var session = new DeviceSession(mockSocket) { IsAuthenticated = false };

        var envelope = new CommandEnvelope
        {
            Version = 1,
            RequestId = "test-123",
            Type = "mouse.move"
        };

        var response = await registry.RouteAsync(envelope, session);

        Assert.False(response.Success);
        Assert.Equal(ErrorCodes.Unauthorized, response.Error?.Code);
    }

    [Fact]
    public void PairingFlow_GeneratesPinAndVerifiesSuccessfully()
    {
        var security = new SecurityManager();
        var deviceId = "phone-" + Guid.NewGuid().ToString("N")[..8];
        var deviceName = "Pixel 8";

        // 1. Initiate pairing
        var pin = security.InitiatePairing(deviceId, deviceName);
        Assert.Equal(6, pin.Length);
        Assert.True(int.TryParse(pin, out _));

        // 2. Incorrect PIN fails
        var verifyFail = security.VerifyPairing(deviceId, "000000", out var badToken, out var errorMsg);
        if (pin != "000000")
        {
            Assert.False(verifyFail);
            Assert.Null(badToken);
            Assert.NotNull(errorMsg);
        }

        // 3. Correct PIN succeeds and returns auth token
        var verifySuccess = security.VerifyPairing(deviceId, pin, out var token, out var successMsg);
        Assert.True(verifySuccess);
        Assert.NotNull(token);
        Assert.Null(successMsg);

        // 4. Authenticate device with issued token
        var authSuccess = security.AuthenticateDevice(deviceId, token, out var record);
        Assert.True(authSuccess);
        Assert.NotNull(record);
        Assert.Equal(deviceName, record.DeviceName);

        // 5. Revoke device
        security.RevokeDevice(deviceId);
        var authAfterRevoke = security.AuthenticateDevice(deviceId, token, out _);
        Assert.False(authAfterRevoke);
    }
}
