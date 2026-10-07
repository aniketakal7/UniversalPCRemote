import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/constants.dart';

class DiscoveredPC {
  final String pcName;
  final String ipAddress;
  final int port;
  final String os;
  final DateTime lastSeen;

  DiscoveredPC({
    required this.pcName,
    required this.ipAddress,
    required this.port,
    required this.os,
    required this.lastSeen,
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

  final StreamController<List<DiscoveredPC>> _pcController =
      StreamController<List<DiscoveredPC>>.broadcast();

  Stream<List<DiscoveredPC>> get discoveredPCsStream => _pcController.stream;
  List<DiscoveredPC> get currentPCs => _discoveredMap.values.toList();
  bool get isSearching => _isSearching;

  Future<void> startDiscovery() async {
    if (_isSearching) return;
    _isSearching = true;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
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
      _queryTimer = Timer.periodic(const Duration(seconds: 2), (_) => sendQuery());

      // Periodically clean up offline PCs
      _cleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        final now = DateTime.now();
        final initialCount = _discoveredMap.length;
        _discoveredMap.removeWhere((_, pc) => now.difference(pc.lastSeen).inSeconds > 10);
        if (_discoveredMap.length != initialCount) {
          _pcController.add(_discoveredMap.values.toList());
        }
      });
    } catch (e) {
      _isSearching = false;
    }
  }

  void sendQuery() {
    if (_socket == null) return;
    try {
      final query = jsonEncode({
        'service': AppConstants.discoveryServiceId,
        'type': 'discovery.query',
      });
      final bytes = utf8.encode(query);
      _socket!.send(
        bytes,
        InternetAddress('255.255.255.255'),
        AppConstants.discoveryPort,
      );
    } catch (_) {}
  }

  void _processDatagram(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;

      if (json['service'] == AppConstants.discoveryServiceId) {
        final pcName = json['pcName'] as String? ?? 'Windows PC';
        final port = json['port'] as int? ?? AppConstants.defaultServerPort;
        final os = json['os'] as String? ?? 'Windows';
        final senderIp = datagram.address.address;

        final pc = DiscoveredPC(
          pcName: pcName,
          ipAddress: senderIp,
          port: port,
          os: os,
          lastSeen: DateTime.now(),
        );

        _discoveredMap[senderIp] = pc;
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
  }

  void dispose() {
    stopDiscovery();
    _pcController.close();
  }
}
