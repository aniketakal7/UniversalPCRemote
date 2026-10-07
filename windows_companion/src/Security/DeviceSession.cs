using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using UniversalPCRemote.Companion.Protocol;

namespace UniversalPCRemote.Companion.Security;

public class DeviceSession
{
    public string ConnectionId { get; } = Guid.NewGuid().ToString("N");
    public WebSocket Socket { get; }
    public string? DeviceId { get; set; }
    public string? DeviceName { get; set; }
    public bool IsAuthenticated { get; set; }
    public DateTime ConnectedAt { get; } = DateTime.UtcNow;
    public DateTime LastActivity { get; set; } = DateTime.UtcNow;

    private readonly SemaphoreSlim _sendLock = new(1, 1);

    public DeviceSession(WebSocket socket)
    {
        Socket = socket;
    }

    public async Task SendResponseAsync(ResponseEnvelope response, CancellationToken cancellationToken = default)
    {
        if (Socket.State != WebSocketState.Open) return;

        var json = JsonSerializer.Serialize(response);
        var bytes = Encoding.UTF8.GetBytes(json);

        await _sendLock.WaitAsync(cancellationToken);
        try
        {
            if (Socket.State == WebSocketState.Open)
            {
                await Socket.SendAsync(
                    new ArraySegment<byte>(bytes),
                    WebSocketMessageType.Text,
                    true,
                    cancellationToken
                );
            }
        }
        finally
        {
            _sendLock.Release();
        }
    }
}
