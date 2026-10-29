using System.Collections.Concurrent;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using UniversalPCRemote.Mac.Logging;
using UniversalPCRemote.Mac.Protocol;
using UniversalPCRemote.Mac.Security;

namespace UniversalPCRemote.Mac.Server;

public class CompanionWebSocketServer
{
    private readonly int _port;
    private readonly CommandRegistry _commandRegistry;
    private readonly ConcurrentDictionary<string, DeviceSession> _activeSessions = new();
    private WebApplication? _app;
    private CancellationTokenSource? _cts;
    private bool _isRunning;

    private const int MaxMessageSizeBytes = 64 * 1024;

    public bool IsRunning => _isRunning;
    public int Port => _port;
    public int ActiveClientCount => _activeSessions.Count;

    public event Action<DeviceSession>? ClientConnected;
    public event Action<DeviceSession>? ClientDisconnected;

    public CompanionWebSocketServer(int port = 51234, CommandRegistry? registry = null)
    {
        _port = port;
        _commandRegistry = registry ?? new CommandRegistry();
    }

    public async Task StartAsync()
    {
        if (_isRunning) return;

        _cts = new CancellationTokenSource();

        try
        {
            var appBuilder = WebApplication.CreateBuilder();
            appBuilder.Logging.ClearProviders();

            appBuilder.WebHost.ConfigureKestrel(options =>
            {
                options.Listen(IPAddress.Any, _port);
                options.Limits.MaxRequestBodySize = MaxMessageSizeBytes;
            });

            _app = appBuilder.Build();

            _app.UseWebSockets(new WebSocketOptions
            {
                KeepAliveInterval = TimeSpan.FromSeconds(5)
            });

            _app.Use(async (context, next) =>
            {
                var path = context.Request.Path.Value?.TrimEnd('/') ?? "";
                if (path.Equals("/remote", StringComparison.OrdinalIgnoreCase) ||
                    path.Equals("/ws", StringComparison.OrdinalIgnoreCase) ||
                    string.IsNullOrEmpty(path))
                {
                    if (context.WebSockets.IsWebSocketRequest)
                    {
                        using var webSocket = await context.WebSockets.AcceptWebSocketAsync();
                        await ProcessClientSocketAsync(webSocket, context.Connection.RemoteIpAddress?.ToString());
                        return;
                    }
                    else
                    {
                        context.Response.Headers["Access-Control-Allow-Origin"] = "*";
                        context.Response.ContentType = "application/json";
                        await context.Response.WriteAsync(JsonSerializer.Serialize(new
                        {
                            service = "UniversalPCRemote",
                            os = "macOS",
                            status = "running",
                            port = _port,
                            clients = _activeSessions.Count,
                            machine = Environment.MachineName
                        }));
                        return;
                    }
                }
                await next();
            });

            await _app.StartAsync(_cts.Token);
            _isRunning = true;
            AppLogger.Instance.Info("Server", $"Companion WebSocket server running on port {_port}.");
        }
        catch (Exception ex)
        {
            _isRunning = false;
            AppLogger.Instance.Error("Server", $"Failed to start server on port {_port}.", ex);
            throw;
        }
    }

    public async Task StopAsync()
    {
        if (!_isRunning) return;
        _isRunning = false;

        try
        {
            _cts?.Cancel();

            foreach (var session in _activeSessions.Values)
            {
                try
                {
                    if (session.Socket.State == WebSocketState.Open)
                    {
                        await session.Socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Server stopping", CancellationToken.None);
                    }
                }
                catch { }
            }
            _activeSessions.Clear();

            if (_app != null)
            {
                await _app.StopAsync(CancellationToken.None);
                await _app.DisposeAsync();
                _app = null;
            }
        }
        catch { }
    }

    private async Task ProcessClientSocketAsync(WebSocket webSocket, string? remoteIp)
    {
        var session = new DeviceSession(webSocket);
        _activeSessions[session.ConnectionId] = session;

        AppLogger.Instance.Info("Server", $"Device connected from {remoteIp ?? "unknown IP"} (ConnID: {session.ConnectionId})");
        ClientConnected?.Invoke(session);

        var buffer = new byte[16384];
        var memoryStream = new MemoryStream(16384);

        try
        {
            while (webSocket.State == WebSocketState.Open && !_cts!.IsCancellationRequested)
            {
                memoryStream.SetLength(0);
                WebSocketReceiveResult result;

                do
                {
                    result = await webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), _cts.Token);
                    if (result.MessageType == WebSocketMessageType.Close) break;

                    memoryStream.Write(buffer, 0, result.Count);
                    if (memoryStream.Length > MaxMessageSizeBytes)
                    {
                        await webSocket.CloseAsync(WebSocketCloseStatus.MessageTooBig, "Message too big", CancellationToken.None);
                        return;
                    }
                } while (!result.EndOfMessage);

                if (result.MessageType == WebSocketMessageType.Close) break;

                if (result.MessageType == WebSocketMessageType.Text)
                {
                    session.LastActivity = DateTime.UtcNow;
                    var messageText = Encoding.UTF8.GetString(memoryStream.GetBuffer(), 0, (int)memoryStream.Length);
                    await HandleIncomingMessageAsync(messageText, session);
                }
            }
        }
        catch { }
        finally
        {
            _activeSessions.TryRemove(session.ConnectionId, out _);
            AppLogger.Instance.Info("Server", $"Device disconnected (ConnID: {session.ConnectionId})");
            ClientDisconnected?.Invoke(session);
        }
    }

    private async Task HandleIncomingMessageAsync(string messageJson, DeviceSession session)
    {
        CommandEnvelope? envelope;
        try
        {
            envelope = JsonSerializer.Deserialize<CommandEnvelope>(messageJson);
        }
        catch (JsonException ex)
        {
            await session.SendResponseAsync(ResponseEnvelope.CreateError(
                Guid.NewGuid().ToString("N"), "unknown", ErrorCodes.InvalidJson, ex.Message
            ));
            return;
        }

        if (envelope == null) return;

        var response = await _commandRegistry.RouteAsync(envelope, session);

        var noResponse = envelope.Payload?.TryGetProperty("_noResponse", out var nr) == true && nr.GetBoolean();
        if (!noResponse || !response.Success)
        {
            await session.SendResponseAsync(response);
        }
    }
}
