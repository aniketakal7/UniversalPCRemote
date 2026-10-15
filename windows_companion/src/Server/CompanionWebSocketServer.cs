using System.Collections.Concurrent;
using System.Net;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using UniversalPCRemote.Companion.Logging;
using UniversalPCRemote.Companion.Protocol;
using UniversalPCRemote.Companion.Security;

namespace UniversalPCRemote.Companion.Server;

public class CompanionWebSocketServer
{
    private readonly int _port;
    private readonly CommandRegistry _commandRegistry;
    private readonly ConcurrentDictionary<string, DeviceSession> _activeSessions = new();
    private readonly object _controllerLock = new();
    private string? _inputControllerConnectionId;
    private DateTime _inputControllerLastActivity = DateTime.MinValue;
    private static readonly TimeSpan InputControlLease = TimeSpan.FromSeconds(10);
    private WebApplication? _app;
    private CancellationTokenSource? _cts;
    private bool _isRunning;

    private const int MaxMessageSizeBytes = 64 * 1024; // 64 KB limit

    public bool IsRunning => _isRunning;
    public int Port => _port;
    public int ActiveClientCount => _activeSessions.Count;
    public IReadOnlyCollection<DeviceSession> ActiveSessions => _activeSessions.Values.ToList();

    public event Action<DeviceSession>? ClientConnected;
    public event Action<DeviceSession>? ClientDisconnected;
    public event Action<bool>? ServerStateChanged;

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
            var appBuilder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = "Production",
                ContentRootPath = AppContext.BaseDirectory
            });

            // Suppress noisy default console logging from ASP.NET Core
            appBuilder.Logging.ClearProviders();

            appBuilder.WebHost.ConfigureKestrel(options =>
            {
                options.Listen(IPAddress.Any, _port);
                options.Limits.MaxRequestBodySize = MaxMessageSizeBytes;
            });

            _app = appBuilder.Build();

            _app.UseWebSockets(new WebSocketOptions
            {
                KeepAliveInterval = TimeSpan.FromSeconds(5),
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
                        // Health check HTTP endpoint
                        context.Response.Headers["Access-Control-Allow-Origin"] = "*";
                        context.Response.ContentType = "application/json";
                        await context.Response.WriteAsync(JsonSerializer.Serialize(new
                        {
                            service = "UniversalPCRemote",
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
            AppLogger.Instance.Info("Server", $"Companion WebSocket server started on port {_port}.");
            ServerStateChanged?.Invoke(true);
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("Server", $"Failed to start server on port {_port}.", ex);
            _isRunning = false;
            ServerStateChanged?.Invoke(false);
            throw;
        }
    }

    public async Task StopAsync()
    {
        if (!_isRunning) return;

        AppLogger.Instance.Info("Server", "Stopping companion server...");
        _isRunning = false;

        try
        {
            _cts?.Cancel();

            // Disconnect all clients gracefully
            foreach (var session in _activeSessions.Values)
            {
                try
                {
                    if (session.Socket.State == WebSocketState.Open)
                    {
                        await session.Socket.CloseAsync(
                            WebSocketCloseStatus.NormalClosure,
                            "Server stopping",
                            CancellationToken.None
                        );
                    }
                }
                catch
                {
                    // Ignore close exceptions during shutdown
                }
            }
            _activeSessions.Clear();

            if (_app != null)
            {
                await _app.StopAsync(CancellationToken.None);
                await _app.DisposeAsync();
                _app = null;
            }

            AppLogger.Instance.Info("Server", "Companion server stopped cleanly.");
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("Server", "Error during server shutdown.", ex);
        }
        finally
        {
            ServerStateChanged?.Invoke(false);
        }
    }

    private async Task ProcessClientSocketAsync(WebSocket webSocket, string? remoteIp)
    {
        var session = new DeviceSession(webSocket);
        _activeSessions[session.ConnectionId] = session;

        AppLogger.Instance.Info("Server", $"Client connected from {remoteIp ?? "unknown IP"} (ConnID: {session.ConnectionId})", connId: session.ConnectionId);
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
                    if (result.MessageType == WebSocketMessageType.Close)
                    {
                        break;
                    }

                    memoryStream.Write(buffer, 0, result.Count);

                    if (memoryStream.Length > MaxMessageSizeBytes)
                    {
                        AppLogger.Instance.Warn("Server", $"Message size exceeded limit ({MaxMessageSizeBytes} bytes). Disconnecting client.", connId: session.ConnectionId);
                        await webSocket.CloseAsync(WebSocketCloseStatus.MessageTooBig, "Message exceeded 64KB limit", CancellationToken.None);
                        return;
                    }
                } while (!result.EndOfMessage);

                if (result.MessageType == WebSocketMessageType.Close)
                {
                    AppLogger.Instance.Info("Server", $"Client requested close: {result.CloseStatusDescription}", connId: session.ConnectionId);
                    break;
                }

                if (result.MessageType == WebSocketMessageType.Text)
                {
                    session.LastActivity = DateTime.UtcNow;
                    var messageText = Encoding.UTF8.GetString(memoryStream.GetBuffer(), 0, (int)memoryStream.Length);
                    await HandleIncomingMessageAsync(messageText, session);
                }
            }
        }
        catch (OperationCanceledException)
        {
            // Server shutting down
        }
        catch (WebSocketException wsex)
        {
            AppLogger.Instance.Warn("Server", $"WebSocket connection error: {wsex.Message}", connId: session.ConnectionId);
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Error("Server", $"Unexpected exception handling client.", ex, connId: session.ConnectionId);
        }
        finally
        {
            ReleaseInputControl(session);
            _activeSessions.TryRemove(session.ConnectionId, out _);
            AppLogger.Instance.Info("Server", $"Client disconnected (ConnID: {session.ConnectionId})", connId: session.ConnectionId);
            ClientDisconnected?.Invoke(session);

            if (webSocket.State == WebSocketState.Open || webSocket.State == WebSocketState.CloseReceived)
            {
                try
                {
                    await webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Closing", CancellationToken.None);
                }
                catch
                {
                    // Suppress
                }
            }
        }
    }

    private async Task HandleIncomingMessageAsync(string messageJson, DeviceSession session)
    {
        CommandEnvelope? envelope;

        try
        {
            envelope = JsonSerializer.Deserialize<CommandEnvelope>(messageJson);
        }
        catch (JsonException jex)
        {
            AppLogger.Instance.Warn("Server", $"Malformed JSON rejected: {jex.Message}", connId: session.ConnectionId);
            var errResponse = ResponseEnvelope.CreateError(
                Guid.NewGuid().ToString("N"),
                "unknown",
                ErrorCodes.InvalidJson,
                $"Malformed JSON packet: {jex.Message}"
            );
            await session.SendResponseAsync(errResponse);
            return;
        }

        if (envelope == null)
        {
            var errResponse = ResponseEnvelope.CreateError(
                Guid.NewGuid().ToString("N"),
                "unknown",
                ErrorCodes.InvalidEnvelope,
                "Null or empty command envelope."
            );
            await session.SendResponseAsync(errResponse);
            return;
        }

        // The PC has one keyboard and pointer.  Keep one client in control for
        // the duration of its socket so simultaneous phones cannot interleave
        // mouse-down/up or keystrokes.
        if (session.IsAuthenticated && IsInputCommand(envelope.Type) && !TryAcquireInputControl(session))
        {
            await session.SendResponseAsync(ResponseEnvelope.CreateError(
                envelope.RequestId,
                envelope.Type,
                ErrorCodes.ControllerInUse,
                "Another connected device is controlling keyboard and mouse input. Disconnect it or wait for it to release the session."
            ));
            return;
        }

        // Route command to command registry.
        var response = await _commandRegistry.RouteAsync(envelope, session);
        if (ShouldRespond(envelope) || !response.Success)
        {
            await session.SendResponseAsync(response);
        }
    }

    private static bool IsInputCommand(string commandType) => commandType is
        CommandTypes.MouseMove or CommandTypes.MouseClick or CommandTypes.MouseDown or
        CommandTypes.MouseUp or CommandTypes.MouseScroll or CommandTypes.KeyboardText or
        CommandTypes.KeyboardKey or CommandTypes.KeyboardCombination;

    private static bool ShouldRespond(CommandEnvelope envelope)
    {
        return envelope.Payload?.TryGetProperty("_noResponse", out var noResponse) != true ||
               noResponse.ValueKind != JsonValueKind.True;
    }

    private bool TryAcquireInputControl(DeviceSession session)
    {
        lock (_controllerLock)
        {
            if (_inputControllerConnectionId == null)
            {
                _inputControllerConnectionId = session.ConnectionId;
            }
            else if (_inputControllerConnectionId != session.ConnectionId &&
                     DateTime.UtcNow - _inputControllerLastActivity > InputControlLease)
            {
                _inputControllerConnectionId = session.ConnectionId;
            }

            var ownsControl = _inputControllerConnectionId == session.ConnectionId;
            if (ownsControl) _inputControllerLastActivity = DateTime.UtcNow;
            return ownsControl;
        }
    }

    private void ReleaseInputControl(DeviceSession session)
    {
        lock (_controllerLock)
        {
            if (_inputControllerConnectionId == session.ConnectionId)
            {
                _inputControllerConnectionId = null;
                _inputControllerLastActivity = DateTime.MinValue;
            }
        }
    }
}
