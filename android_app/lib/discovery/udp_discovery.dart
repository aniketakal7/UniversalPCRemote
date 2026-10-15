import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/constants.dart';
import 'wifi_multicast_lock.dart';

class DiscoveredPC {
  final String pcName;
  final String ipAddress;
  final int port;
  final String os;
  final DateTime lastSeen;
  final bool isHotspot;

  DiscoveredPC({
    required this.pcName,
    required this.ipAddress,
    required this.port,
    required this.os,
    required this.lastSeen,
    this.isHotspot = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredPC &&
          runtimeType == other.runtimeType &&
          ipAddress == other.ipAddress &&
          port == other.port;

  @override
  int get hashCode => ipAddress.hashCode ^ port.hashCode;
}

class UdpDiscoveryService {
  RawDatagramSocket? _socket;
  final Map<String, DiscoveredPC> _discoveredMap = {};
  Timer? _queryTimer;
  Timer? _cleanupTimer;
  bool _isSearching = false;

  bool _isHotspotActive = false;
  String? _hotspotSubnet;
  String? _hotspotGatewayIp;
  bool _isHotspotScanning = false;

  final StreamController<List<DiscoveredPC>> _pcController =
      StreamController<List<DiscoveredPC>>.broadcast();

  Stream<List<DiscoveredPC>> get discoveredPCsStream => _pcController.stream;
  List<DiscoveredPC> get currentPCs => _discoveredMap.values.toList();
  bool get isSearching => _isSearching;

  bool get isHotspotActive => _isHotspotActive;
  String? get hotspotSubnet => _hotspotSubnet;
  String? get hotspotGatewayIp => _hotspotGatewayIp;
  bool get isHotspotScanning => _isHotspotScanning;

  Future<void> startDiscovery() async {
    if (_isSearching) return;
    _isSearching = true;

    try {
      await WifiMulticastLock.acquire();
      await _checkNetworkInterfaces();

      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket!.broadcastEnabled = true;

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _processDatagram(datagram);
          }
        }
      });

      // Send initial discovery queries
      sendQuery();
      _queryTimer =
          Timer.periodic(const Duration(seconds: 2), (_) => sendQuery());

      // Periodically clean up offline PCs
      _cleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        final now = DateTime.now();
        final initialCount = _discoveredMap.length;
        _discoveredMap
            .removeWhere((_, pc) => now.difference(pc.lastSeen).inSeconds > 10);
        if (_discoveredMap.length != initialCount) {
          _pcController.add(_discoveredMap.values.toList());
        }
      });

      // If phone is in hotspot mode, auto-trigger a quick client scan
      if (_isHotspotActive) {
        unawaited(scanHotspotSubnet());
      }
    } catch (e) {
      _isSearching = false;
      await WifiMulticastLock.release();
    }
  }

  final Set<String> _localIps = {};
  final Set<String> _activeSubnets = {};

  Future<void> _checkNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      _localIps.clear();
      _activeSubnets.clear();
      bool foundHotspot = false;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('127.') || ip.startsWith('169.254.')) continue;

          _localIps.add(ip);
          final parts = ip.split('.');
          if (parts.length == 4) {
            _activeSubnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
          }

          final isTetherIface = name.contains('ap') ||
              name.contains('tether') ||
              name.contains('rndis') ||
              name.contains('softap');
          final isHotspotIp = ip.startsWith('192.168.43.') ||
              ip.startsWith('192.168.225.') ||
              ip.startsWith('192.168.44.') ||
              ip.startsWith('192.168.50.') ||
              (isTetherIface && ip.endsWith('.1'));

          if (isHotspotIp) {
            foundHotspot = true;
            _hotspotGatewayIp = ip;
            if (parts.length == 4) {
              _hotspotSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
      _isHotspotActive = foundHotspot;
    } catch (_) {}
  }

  void sendQuery() async {
    if (_socket == null) return;
    try {
      await _checkNetworkInterfaces();

      final query = jsonEncode({
        'service': AppConstants.discoveryServiceId,
        'type': 'discovery.query',
      });
      final bytes = utf8.encode(query);

      // 1. Global broadcast
      _socket!.send(
        bytes,
        InternetAddress('255.255.255.255'),
        AppConstants.discoveryPort,
      );

      // 2. Subnet-directed broadcast for all local network subnets (e.g. 192.168.1.255)
      // Essential because many Wi-Fi routers block global broadcast between wireless clients
      final subnetsToBroadcast = Set<String>.from(_activeSubnets);
      if (_hotspotSubnet != null) {
        subnetsToBroadcast.add(_hotspotSubnet!);
      }

      for (final subnet in subnetsToBroadcast) {
        try {
          _socket!.send(
            bytes,
            InternetAddress('$subnet.255'),
            AppConstants.discoveryPort,
          );
        } catch (_) {}
      }

      // 3. Hotspot candidate probes if hotspot active
      if (_isHotspotActive) {
        _probeHotspotCandidates(bytes);
      }
    } catch (_) {}
  }

  void _probeHotspotCandidates(List<int> queryBytes) {
    if (_socket == null) return;
    final subnet = _hotspotSubnet ?? '192.168.43';
    // Send quick UDP discovery packets to the most likely DHCP client IPs
    for (int i = 2; i <= 35; i++) {
      try {
        _socket!.send(
          queryBytes,
          InternetAddress('$subnet.$i'),
          AppConstants.discoveryPort,
        );
      } catch (_) {}
    }
  }

  /// Active parallel probe across hotspot subnet (both UDP query and fast TCP socket check)
  /// Guarantees discovering the connected PC even if the mobile hotspot AP drops broadcast packets.
  Future<void> scanHotspotSubnet() async {
    if (_isHotspotScanning) return;
    _isHotspotScanning = true;
    _pcController.add(_discoveredMap.values.toList());

    try {
      await _checkNetworkInterfaces();
      final subnet = _hotspotSubnet ?? '192.168.43';

      final query = jsonEncode({
        'service': AppConstants.discoveryServiceId,
        'type': 'discovery.query',
      });
      final queryBytes = utf8.encode(query);

      // 1. Fast UDP flood to DHCP pool
      if (_socket != null) {
        for (int i = 2; i <= 40; i++) {
          try {
            _socket!.send(
              queryBytes,
              InternetAddress('$subnet.$i'),
              AppConstants.discoveryPort,
            );
          } catch (_) {}
        }
      }

      // 2. Parallel TCP connect probe to port 51234 on candidate IPs
      final candidates = <String>[];
      for (int i = 2; i <= 35; i++) {
        candidates.add('$subnet.$i');
      }

      final futures = candidates.map((ip) async {
        try {
          final socket = await Socket.connect(
            ip,
            AppConstants.defaultServerPort,
            timeout: const Duration(milliseconds: 350),
          );
          socket.destroy();

          // Port 51234 responded! Windows Companion is active!
          final pc = DiscoveredPC(
            pcName: 'Windows PC (Hotspot)',
            ipAddress: ip,
            port: AppConstants.defaultServerPort,
            os: 'Windows',
            lastSeen: DateTime.now(),
            isHotspot: true,
          );
          _discoveredMap[ip] = pc;
          _pcController.add(_discoveredMap.values.toList());
        } catch (_) {}
      });

      await Future.wait(futures);
    } catch (_) {
    } finally {
      _isHotspotScanning = false;
      _pcController.add(_discoveredMap.values.toList());
    }
  }

  void _processDatagram(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;

      if (json['service'] == AppConstants.discoveryServiceId) {
        // Discard queries originating from phones (including self-broadcast echoes)
        if (json['type'] == 'discovery.query') return;

        final senderIp = datagram.address.address;
        // Never discover this phone itself
        if (_localIps.contains(senderIp)) return;

        final pcName = json['pcName'] as String? ?? 'Windows PC';
        final port = json['port'] as int? ?? AppConstants.defaultServerPort;
        final os = json['os'] as String? ?? 'Windows';
        final isHotspotFromPayload = json['isHotspot'] as bool? ?? false;
        final isHotspotIp = senderIp.startsWith('192.168.43.') ||
            senderIp.startsWith('192.168.225.') ||
            senderIp.startsWith('192.168.44.') ||
            senderIp.startsWith('192.168.50.') ||
            senderIp.startsWith('192.168.137.') ||
            (_hotspotSubnet != null && senderIp.startsWith(_hotspotSubnet!));

        // If beacon provided reachable IP addresses, check if any matches this phone's subnet
        var targetIp = senderIp;
        final addresses = (json['addresses'] as List?)?.cast<String>();
        if (addresses != null && addresses.isNotEmpty && !addresses.contains(senderIp)) {
          final matched = addresses.firstWhere(
            (addr) => _activeSubnets.any((sub) => addr.startsWith('$sub.')),
            orElse: () => senderIp,
          );
          targetIp = matched;
        }

        final pc = DiscoveredPC(
          pcName: pcName,
          ipAddress: targetIp,
          port: port,
          os: os,
          lastSeen: DateTime.now(),
          isHotspot: isHotspotFromPayload || isHotspotIp,
        );

        _discoveredMap[targetIp] = pc;
        _pcController.add(_discoveredMap.values.toList());
      }
    } catch (_) {}
  }

  void stopDiscovery() {
    _isSearching = false;
    _queryTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
    WifiMulticastLock.release();
  }

  void dispose() {
    stopDiscovery();
    _pcController.close();
  }
}
