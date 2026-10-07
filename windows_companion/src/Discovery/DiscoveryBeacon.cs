using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using UniversalPCRemote.Companion.Logging;

namespace UniversalPCRemote.Companion.Discovery;

public class DiscoveryBeacon : IDisposable
{
    private readonly int _serverPort;
    private readonly int _discoveryPort;
    private UdpClient? _udpClient;
    private CancellationTokenSource? _cts;
    private bool _isRunning;

    public const string ServiceIdentifier = "UniversalPCRemote";

    public DiscoveryBeacon(int serverPort = 51234, int discoveryPort = 51235)
    {
        _serverPort = serverPort;
        _discoveryPort = discoveryPort;
    }

    public void Start()
    {
        if (_isRunning) return;

        _cts = new CancellationTokenSource();
        _isRunning = true;

        Task.Run(() => ListenForDiscoveryQueriesAsync(_cts.Token));
        Task.Run(() => PeriodicBroadcastAsync(_cts.Token));

        AppLogger.Instance.Info("Discovery", $"Discovery beacon active on UDP port {_discoveryPort}.");
    }

    public void Stop()
    {
        _isRunning = false;
        _cts?.Cancel();
        _udpClient?.Dispose();
        _udpClient = null;
        AppLogger.Instance.Info("Discovery", "Discovery beacon stopped.");
    }

    private async Task ListenForDiscoveryQueriesAsync(CancellationToken token)
    {
        try
        {
            _udpClient = new UdpClient();
            _udpClient.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
            _udpClient.Client.Bind(new IPEndPoint(IPAddress.Any, _discoveryPort));

            while (!token.IsCancellationRequested)
            {
                var result = await _udpClient.ReceiveAsync(token);
                var queryText = Encoding.UTF8.GetString(result.Buffer);

                if (queryText.Contains(ServiceIdentifier))
                {
                    // Respond directly to the querying client
                    var responseBytes = CreateBeaconPayloadBytes();
                    await _udpClient.SendAsync(responseBytes, responseBytes.Length, result.RemoteEndPoint);
                    AppLogger.Instance.Debug("Discovery", $"Responded to discovery query from {result.RemoteEndPoint}");
                }
            }
        }
        catch (OperationCanceledException)
        {
            // Normal shutdown
        }
        catch (Exception ex)
        {
            if (_isRunning)
            {
                AppLogger.Instance.Error("Discovery", "UDP discovery listener error.", ex);
            }
        }
    }

    private async Task PeriodicBroadcastAsync(CancellationToken token)
    {
        using var broadcastClient = new UdpClient();
        broadcastClient.EnableBroadcast = true;
        var broadcastEndpoint = new IPEndPoint(IPAddress.Broadcast, _discoveryPort);

        while (!token.IsCancellationRequested)
        {
            try
            {
                var payload = CreateBeaconPayloadBytes();
                await broadcastClient.SendAsync(payload, payload.Length, broadcastEndpoint);
                await Task.Delay(3000, token);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                AppLogger.Instance.Debug("Discovery", $"Periodic broadcast notice: {ex.Message}");
                await Task.Delay(5000, token);
            }
        }
    }

    private byte[] CreateBeaconPayloadBytes()
    {
        var localIps = GetLocalIpAddresses();
        var announcement = new
        {
            service = ServiceIdentifier,
            version = 1,
            pcName = Environment.MachineName,
            port = _serverPort,
            os = "Windows",
            addresses = localIps
        };

        var json = JsonSerializer.Serialize(announcement);
        return Encoding.UTF8.GetBytes(json);
    }

    public static List<string> GetLocalIpAddresses()
    {
        var ips = new List<string>();
        try
        {
            var host = Dns.GetHostEntry(Dns.GetHostName());
            foreach (var ip in host.AddressList)
            {
                if (ip.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(ip))
                {
                    ips.Add(ip.ToString());
                }
            }
        }
        catch
        {
            // Suppress DNS lookup failures
        }
        return ips;
    }

    public void Dispose()
    {
        Stop();
    }
}
