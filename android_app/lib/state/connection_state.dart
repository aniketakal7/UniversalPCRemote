import 'dart:async';
import 'package:flutter/foundation.dart';
import '../discovery/udp_discovery.dart';
import '../network/remote_client.dart';
import '../pairing/pairing_manager.dart';

enum AppConnectionStatus {
  disconnected,
  discovering,
  connecting,
  pairingRequired,
  authenticating,
  connected,
  reconnecting,
  error,
}

class ConnectionStateManager extends ChangeNotifier {
  final RemoteClient client = RemoteClient();
  final UdpDiscoveryService discovery = UdpDiscoveryService();
  final PairingManager pairing = PairingManager();

  AppConnectionStatus _status = AppConnectionStatus.disconnected;
  String? _errorMessage;
  String? _activeIp;
  String? _connectedPcName;
  double _mouseSensitivity = 1.2;

  StreamSubscription? _clientStateSub;
  StreamSubscription? _discoverySub;

  AppConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get activeIp => _activeIp;
  String? get connectedPcName => _connectedPcName;
  double get mouseSensitivity => _mouseSensitivity;
  bool get isConnected => _status == AppConnectionStatus.connected;

  ConnectionStateManager() {
    _init();
  }

  Future<void> _init() async {
    await pairing.init();

    _clientStateSub = client.stateStream.listen((clientState) {
      switch (clientState) {
        case ClientConnectionState.connected:
          // Socket opened, will proceed with auth/pairing check
          break;
        case ClientConnectionState.reconnecting:
          _setStatus(AppConnectionStatus.reconnecting);
          break;
        case ClientConnectionState.disconnected:
          if (_status == AppConnectionStatus.connected) {
            _setStatus(AppConnectionStatus.disconnected);
          }
          break;
        case ClientConnectionState.error:
          _setStatus(AppConnectionStatus.error, 'Network error connecting to PC.');
          break;
        case ClientConnectionState.connecting:
          _setStatus(AppConnectionStatus.connecting);
          break;
      }
    });
  }

  void setSensitivity(double value) {
    _mouseSensitivity = value.clamp(0.2, 3.0);
    notifyListeners();
  }

  void _setStatus(AppConnectionStatus newStatus, [String? error]) {
    _status = newStatus;
    _errorMessage = error;
    notifyListeners();
  }

  Future<void> startDiscovery() async {
    _setStatus(AppConnectionStatus.discovering);
    await discovery.startDiscovery();
  }

  void stopDiscovery() {
    discovery.stopDiscovery();
    if (_status == AppConnectionStatus.discovering) {
      _setStatus(AppConnectionStatus.disconnected);
    }
  }

  Future<void> connectToPC(String ip, [int port = 51234, String? pcName]) async {
    _activeIp = ip;
    _connectedPcName = pcName ?? ip;
    _setStatus(AppConnectionStatus.connecting);

    try {
      await client.connect(ip, port);

      // Check if already paired
      if (pairing.isPairedWith(ip)) {
        _setStatus(AppConnectionStatus.authenticating);
        final authOk = await pairing.authenticate(client, ip);
        if (authOk) {
          _setStatus(AppConnectionStatus.connected);
          return;
        } else {
          // Token revoked or expired; require re-pairing
          await pairing.forgetDevice(ip);
        }
      }

      // Not paired or token revoked -> initiate pairing
      _setStatus(AppConnectionStatus.pairingRequired);
      await pairing.initiatePairing(client, 'Android Remote');
    } catch (e) {
      _setStatus(AppConnectionStatus.error, 'Failed to connect to $ip: $e');
    }
  }

  Future<bool> submitPairingPin(String pin) async {
    if (_activeIp == null) return false;

    try {
      final success = await pairing.verifyPairing(client, _activeIp!, pin);
      if (success) {
        _setStatus(AppConnectionStatus.connected);
        return true;
      } else {
        _errorMessage = 'Invalid pairing PIN. Check the PC companion screen.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Pairing error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await client.disconnect();
    _setStatus(AppConnectionStatus.disconnected);
  }

  @override
  void dispose() {
    _clientStateSub?.cancel();
    _discoverySub?.cancel();
    client.dispose();
    discovery.dispose();
    super.dispose();
  }
}
