using System.Net.WebSockets;
using System.Text.Json;
using UniversalPCRemote.Mac.Protocol;

namespace UniversalPCRemote.Mac.Security;

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
    private readonly MemoryStream _sendBuffer = new(1024);

    public DeviceSession(WebSocket socket)
    {
        Socket = socket;
    }

    public async Task SendResponseAsync(ResponseEnvelope response, CancellationToken cancellationToken = default)
    {
        if (Socket.State != WebSocketState.Open) return;

        await _sendLock.WaitAsync(cancellationToken);
        try
        {
            if (Socket.State == WebSocketState.Open)
            {
                _sendBuffer.SetLength(0);
                JsonSerializer.Serialize(_sendBuffer, response);

                await Socket.SendAsync(
                    new ArraySegment<byte>(_sendBuffer.GetBuffer(), 0, (int)_sendBuffer.Length),
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
