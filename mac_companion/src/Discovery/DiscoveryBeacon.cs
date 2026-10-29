using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using UniversalPCRemote.Mac.Logging;

namespace UniversalPCRemote.Mac.Discovery;

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

        AppLogger.Instance.Info("Discovery", $"macOS Discovery Beacon active on UDP port {_discoveryPort}.");
    }

    public void Stop()
    {
        _isRunning = false;
        _cts?.Cancel();
        _udpClient?.Dispose();
        _udpClient = null;
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
                var receiveResult = await _udpClient.ReceiveAsync(token);
                var message = Encoding.UTF8.GetString(receiveResult.Buffer);

                if (message.Contains(ServiceIdentifier, StringComparison.OrdinalIgnoreCase) ||
                    message.Contains("discovery.query", StringComparison.OrdinalIgnoreCase))
                {
                    var responseBytes = CreateBeaconPayloadBytes();
                    await _udpClient.SendAsync(responseBytes, responseBytes.Length, receiveResult.RemoteEndPoint);
                }
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            AppLogger.Instance.Debug("Discovery", $"Discovery listener notice: {ex.Message}");
        }
    }

    private async Task PeriodicBroadcastAsync(CancellationToken token)
    {
        using var broadcastClient = new UdpClient();
        broadcastClient.EnableBroadcast = true;

        while (!token.IsCancellationRequested)
        {
            try
            {
                var payload = CreateBeaconPayloadBytes();
                var targets = GetBroadcastEndpoints(_discoveryPort);

                foreach (var ep in targets)
                {
                    try { await broadcastClient.SendAsync(payload, payload.Length, ep); }
                    catch { }
                }

                await Task.Delay(2500, token);
            }
            catch (OperationCanceledException) { break; }
            catch { await Task.Delay(5000, token); }
        }
    }

    private byte[] CreateBeaconPayloadBytes()
    {
        var localIps = GetLocalIpAddresses();

        var announcement = new
        {
            service = ServiceIdentifier,
            type = "discovery.announcement",
            version = 1,
            pcName = Environment.MachineName,
            port = _serverPort,
            os = "macOS",
            addresses = localIps,
            isHotspot = false,
            hotspotGateway = (string?)null,
            hotspotPcIp = (string?)null
        };

        var json = JsonSerializer.Serialize(announcement);
        return Encoding.UTF8.GetBytes(json);
    }

    public static List<IPEndPoint> GetBroadcastEndpoints(int port)
    {
        var endpoints = new HashSet<IPEndPoint> { new IPEndPoint(IPAddress.Broadcast, port) };

        try
        {
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus != OperationalStatus.Up || ni.NetworkInterfaceType == NetworkInterfaceType.Loopback)
                    continue;

                foreach (var u in ni.GetIPProperties().UnicastAddresses)
                {
                    if (u.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(u.Address))
                    {
                        if (u.IPv4Mask != null)
                        {
                            var ipBytes = u.Address.GetAddressBytes();
                            var maskBytes = u.IPv4Mask.GetAddressBytes();
                            var broadcastBytes = new byte[4];
                            for (int i = 0; i < 4; i++)
                                broadcastBytes[i] = (byte)(ipBytes[i] | ~maskBytes[i]);
                            endpoints.Add(new IPEndPoint(new IPAddress(broadcastBytes), port));
                        }
                    }
                }
            }
        }
        catch { }

        return endpoints.ToList();
    }

    public static List<string> GetLocalIpAddresses()
    {
        var ips = new List<string>();
        try
        {
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus != OperationalStatus.Up || ni.NetworkInterfaceType == NetworkInterfaceType.Loopback)
                    continue;

                foreach (var u in ni.GetIPProperties().UnicastAddresses)
                {
                    if (u.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(u.Address))
                        ips.Add(u.Address.ToString());
                }
            }
        }
        catch { }
        return ips;
    }

    public void Dispose() => Stop();
}
