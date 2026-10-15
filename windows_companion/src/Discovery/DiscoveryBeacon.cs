using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using UniversalPCRemote.Companion.Logging;

namespace UniversalPCRemote.Companion.Discovery;

public record HotspotNetworkInfo(bool IsConnected, string? PcIp, string? PhoneGatewayIp, string? InterfaceName);

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

        var hotspot = GetHotspotInfo();
        if (hotspot.IsConnected)
        {
            AppLogger.Instance.Info("Discovery", $"Phone Hotspot network detected! PC IP: {hotspot.PcIp}, Phone Gateway: {hotspot.PhoneGatewayIp} on {hotspot.InterfaceName}");
        }

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

                if (queryText.Contains(ServiceIdentifier) && queryText.Contains("discovery.query"))
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

        while (!token.IsCancellationRequested)
        {
            try
            {
                var payload = CreateBeaconPayloadBytes();
                var targets = GetBroadcastAndGatewayEndpoints(_discoveryPort);

                foreach (var ep in targets)
                {
                    try
                    {
                        await broadcastClient.SendAsync(payload, payload.Length, ep);
                    }
                    catch
                    {
                        // Some secondary adapter endpoints may fail silently; ignore
                    }
                }

                await Task.Delay(2500, token);
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
        var hotspot = GetHotspotInfo();

        var announcement = new
        {
            service = ServiceIdentifier,
            type = "discovery.announcement",
            version = 1,
            pcName = Environment.MachineName,
            port = _serverPort,
            os = "Windows",
            addresses = localIps,
            isHotspot = hotspot.IsConnected,
            hotspotGateway = hotspot.PhoneGatewayIp,
            hotspotPcIp = hotspot.PcIp
        };

        var json = JsonSerializer.Serialize(announcement);
        return Encoding.UTF8.GetBytes(json);
    }

    /// <summary>
    /// Collects global broadcast, subnet-directed broadcasts, and phone hotspot gateway IPs.
    /// Default gateway unicast is used only when an actual mobile hotspot is detected.
    /// </summary>
    public static List<IPEndPoint> GetBroadcastAndGatewayEndpoints(int port)
    {
        var endpoints = new HashSet<IPEndPoint>();
        endpoints.Add(new IPEndPoint(IPAddress.Broadcast, port));

        try
        {
            var hotspot = GetHotspotInfo();
            if (hotspot.IsConnected && !string.IsNullOrEmpty(hotspot.PhoneGatewayIp) &&
                IPAddress.TryParse(hotspot.PhoneGatewayIp, out var hotspotGwIp))
            {
                endpoints.Add(new IPEndPoint(hotspotGwIp, port));
            }

            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus != OperationalStatus.Up || ni.NetworkInterfaceType == NetworkInterfaceType.Loopback)
                    continue;

                var ipProps = ni.GetIPProperties();

                // Subnet-directed broadcast (e.g. 192.168.1.255, 192.168.43.255)
                foreach (var u in ipProps.UnicastAddresses)
                {
                    if (u.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(u.Address))
                    {
                        var ipStr = u.Address.ToString();
                        if (ipStr.StartsWith("169.254.")) continue; // skip APIPA / disconnected link-local

                        if (u.IPv4Mask != null)
                        {
                            var ipBytes = u.Address.GetAddressBytes();
                            var maskBytes = u.IPv4Mask.GetAddressBytes();
                            if (ipBytes.Length == 4 && maskBytes.Length == 4)
                            {
                                var bcastBytes = new byte[4];
                                for (int i = 0; i < 4; i++)
                                {
                                    bcastBytes[i] = (byte)(ipBytes[i] | ~maskBytes[i]);
                                }
                                endpoints.Add(new IPEndPoint(new IPAddress(bcastBytes), port));
                            }
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            AppLogger.Instance.Debug("Discovery", $"Error resolving network endpoints: {ex.Message}");
        }

        return endpoints.ToList();
    }

    /// <summary>
    /// Detects whether this PC is connected to an Android/Phone Mobile Hotspot or Tethering interface.
    /// </summary>
    public static HotspotNetworkInfo GetHotspotInfo()
    {
        try
        {
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus != OperationalStatus.Up || ni.NetworkInterfaceType == NetworkInterfaceType.Loopback)
                    continue;

                var ipProps = ni.GetIPProperties();
                var desc = (ni.Description + " " + ni.Name).ToLowerInvariant();
                var isExplicitHotspotOrTether = desc.Contains("rndis") || desc.Contains("tether") || desc.Contains("remote ndis") || desc.Contains("softap") || desc.Contains("hotspot");

                foreach (var gw in ipProps.GatewayAddresses)
                {
                    if (gw.Address.AddressFamily != AddressFamily.InterNetwork) continue;

                    var gwStr = gw.Address.ToString();
                    // Common Android / phone hotspot gateway subnets:
                    // 192.168.43.1 (Google Pixel, Samsung, Motorola, Xiaomi, OnePlus default)
                    // 192.168.225.1 (Jio/Reliance)
                    // 192.168.44.1 / 192.168.50.1 / 192.168.137.1
                    bool isKnownHotspotSubnet = gwStr.StartsWith("192.168.43.") ||
                                                gwStr.StartsWith("192.168.225.") ||
                                                gwStr.StartsWith("192.168.44.") ||
                                                gwStr.StartsWith("192.168.50.") ||
                                                gwStr.StartsWith("192.168.137.");

                    if (isKnownHotspotSubnet || (isExplicitHotspotOrTether && gwStr.EndsWith(".1")))
                    {
                        var pcIp = ipProps.UnicastAddresses
                            .FirstOrDefault(u => u.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(u.Address) && !u.Address.ToString().StartsWith("169.254."))
                            ?.Address.ToString();

                        return new HotspotNetworkInfo(true, pcIp, gwStr, ni.Name);
                    }
                }
            }
        }
        catch
        {
            // Suppress network inspect failures
        }

        return new HotspotNetworkInfo(false, null, null, null);
    }

    public static List<string> GetLocalIpAddresses()
    {
        var ips = new List<string>();
        try
        {
            var hotspot = GetHotspotInfo();
            if (hotspot.IsConnected && !string.IsNullOrEmpty(hotspot.PcIp) && !ips.Contains(hotspot.PcIp))
            {
                ips.Add(hotspot.PcIp);
            }

            // Prefer network interfaces that are Up, non-loopback, and have an IPv4 address with a default gateway
            var interfaces = NetworkInterface.GetAllNetworkInterfaces()
                .Where(ni => ni.OperationalStatus == OperationalStatus.Up && ni.NetworkInterfaceType != NetworkInterfaceType.Loopback)
                .ToList();

            // First pass: interfaces with default gateways (connected to active LAN/Wi-Fi)
            foreach (var ni in interfaces)
            {
                var props = ni.GetIPProperties();
                if (props.GatewayAddresses.Any(g => g.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(g.Address)))
                {
                    foreach (var u in props.UnicastAddresses)
                    {
                        if (u.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(u.Address))
                        {
                            var ipStr = u.Address.ToString();
                            if (!ipStr.StartsWith("169.254.") && !ips.Contains(ipStr))
                            {
                                ips.Add(ipStr);
                            }
                        }
                    }
                }
            }

            // Second pass: any other valid interface (excluding APIPA and loopback)
            foreach (var ni in interfaces)
            {
                var props = ni.GetIPProperties();
                foreach (var u in props.UnicastAddresses)
                {
                    if (u.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(u.Address))
                    {
                        var ipStr = u.Address.ToString();
                        if (!ipStr.StartsWith("169.254.") && !ips.Contains(ipStr))
                        {
                            ips.Add(ipStr);
                        }
                    }
                }
            }
        }
        catch
        {
            // Suppress network inspect failures
        }
        return ips;
    }

    public void Dispose()
    {
        Stop();
    }
}
