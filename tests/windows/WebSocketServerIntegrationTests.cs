using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;
using UniversalPCRemote.Companion.Server;

namespace UniversalPCRemote.Tests;

public class WebSocketServerIntegrationTests
{
    [Fact]
    public async Task Client_CanConnect_SendPing_ReceivePong()
    {
        var security = new SecurityManager();
        var registry = new CommandRegistry(security);
        var authHandler = new AuthCommandHandler(security);

        registry.Register(CommandTypes.AuthPairRequest, authHandler);
        registry.Register(CommandTypes.AuthPairVerify, authHandler);
        registry.Register(CommandTypes.AuthAuthenticate, authHandler);
        registry.Register(CommandTypes.SessionPing, authHandler);

        // Use test port 51239 to avoid conflicts
        var server = new CompanionWebSocketServer(51239, registry);
        await server.StartAsync();

        try
        {
            using var client = new ClientWebSocket();
            var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));

            await client.ConnectAsync(new Uri("ws://127.0.0.1:51239/remote"), cts.Token);
            Assert.Equal(WebSocketState.Open, client.State);

            // Send ping command
            var pingCommand = new
            {
                version = 1,
                requestId = "test-ping-1",
                type = CommandTypes.SessionPing,
                timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                payload = new { }
            };

            var json = JsonSerializer.Serialize(pingCommand);
            var sendBytes = Encoding.UTF8.GetBytes(json);
            await client.SendAsync(new ArraySegment<byte>(sendBytes), WebSocketMessageType.Text, true, cts.Token);

            // Receive response
            var buffer = new byte[4096];
            var receiveResult = await client.ReceiveAsync(new ArraySegment<byte>(buffer), cts.Token);
            Assert.Equal(WebSocketMessageType.Text, receiveResult.MessageType);

            var responseJson = Encoding.UTF8.GetString(buffer, 0, receiveResult.Count);
            var response = JsonSerializer.Deserialize<ResponseEnvelope>(responseJson);

            Assert.NotNull(response);
            Assert.True(response.Success);
            Assert.Equal("test-ping-1", response.RequestId);
            Assert.Equal(CommandTypes.SessionPong, response.Type);

            await client.CloseAsync(WebSocketCloseStatus.NormalClosure, "Done", CancellationToken.None);
        }
        finally
        {
            await server.StopAsync();
        }
    }

    [Fact]
    public async Task MalformedJson_ReturnsStandardErrorResponse()
    {
        var registry = new CommandRegistry();
        var server = new CompanionWebSocketServer(51238, registry);
        await server.StartAsync();

        try
        {
            using var client = new ClientWebSocket();
            var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));

            await client.ConnectAsync(new Uri("ws://127.0.0.1:51238/remote"), cts.Token);
            Assert.Equal(WebSocketState.Open, client.State);

            // Send broken JSON
            var badBytes = Encoding.UTF8.GetBytes("{ not valid json at all ... ");
            await client.SendAsync(new ArraySegment<byte>(badBytes), WebSocketMessageType.Text, true, cts.Token);

            var buffer = new byte[4096];
            var receiveResult = await client.ReceiveAsync(new ArraySegment<byte>(buffer), cts.Token);
            var responseJson = Encoding.UTF8.GetString(buffer, 0, receiveResult.Count);
            var response = JsonSerializer.Deserialize<ResponseEnvelope>(responseJson);

            Assert.NotNull(response);
            Assert.False(response.Success);
            Assert.Equal(ErrorCodes.InvalidJson, response.Error?.Code);

            await client.CloseAsync(WebSocketCloseStatus.NormalClosure, "Done", CancellationToken.None);
        }
        finally
        {
            await server.StopAsync();
        }
    }
}
