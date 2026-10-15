import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../core/app_haptics.dart';
import '../discovery/udp_discovery.dart';
import '../network/remote_client.dart';
import '../pairing/pairing_manager.dart';
import '../protocol/models.dart';
import '../services/remote_foreground_service.dart';

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
  double _mouseSensitivity = 1.4;

  StreamSubscription? _clientStateSub;
  StreamSubscription? _discoverySub;
  bool _isConnecting = false;
  bool _isRestoringSession = false;
  bool _automaticReconnectEnabled = true;
  bool isPairingDialogShowing = false;

  AppConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get activeIp => _activeIp;
  String? get connectedPcName => _connectedPcName;
  String get displayName => _connectedPcName ?? _activeIp ?? 'Windows PC';
  double get mouseSensitivity => _mouseSensitivity;
  bool get isConnected => _status == AppConnectionStatus.connected;
  bool get isConnecting =>
      _status == AppConnectionStatus.connecting ||
      _status == AppConnectionStatus.authenticating ||
      _status == AppConnectionStatus.reconnecting;

  bool get isHotspotActive => discovery.isHotspotActive;
  String? get hotspotSubnet => discovery.hotspotSubnet;
  String? get hotspotGatewayIp => discovery.hotspotGatewayIp;
  bool get isHotspotScanning => discovery.isHotspotScanning;

  Future<void> scanHotspot() async {
    await discovery.scanHotspotSubnet();
    notifyListeners();
  }

  HapticMode get hapticMode => AppHaptics.currentMode;

  ConnectionStateManager() {
    _init();
  }

  Future<void> _init() async {
    FlutterForegroundTask.addTaskDataCallback(_onForegroundTaskAction);
    await AppHaptics.init();
    await pairing.init();

    _clientStateSub = client.stateStream.listen((clientState) {
      switch (clientState) {
        case ClientConnectionState.connected:
          if (!_isConnecting) {
            unawaited(_restoreSessionAfterReconnect());
          }
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

    _discoverySub = discovery.discoveredPCsStream.listen(_reconnectToDiscoveredPairedPc);

    // A previously paired PC reconnects automatically when it is reachable on
    // the same Wi-Fi. Discovery stays active to retry it after a network change.
    if (pairing.pairedPcs.isNotEmpty) {
      unawaited(discovery.startDiscovery());
      unawaited(_connectToMostRecentPairedPc());
    }
  }

  void setSensitivity(double value) {
    _mouseSensitivity = value.clamp(0.4, 3.0);
    notifyListeners();
  }

  void setHapticMode(HapticMode mode) {
    AppHaptics.setMode(mode);
    notifyListeners();
  }

  void _setStatus(AppConnectionStatus newStatus, [String? error]) {
    _status = newStatus;
    _errorMessage = error;
    if (newStatus != AppConnectionStatus.pairingRequired) {
      isPairingDialogShowing = false;
    }
    if (newStatus == AppConnectionStatus.connected) {
      unawaited(RemoteForegroundService.startService(
        pcName: displayName,
        host: _activeIp ?? 'LAN',
      ));
    } else if (newStatus == AppConnectionStatus.disconnected ||
        newStatus == AppConnectionStatus.error) {
      unawaited(RemoteForegroundService.stopService());
    }
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
    _automaticReconnectEnabled = true;

    await _connectAndAuthenticate(ip, port);
  }

  Future<void> _connectAndAuthenticate(String ip, int port) async {
    if (_isConnecting) return;
    _isConnecting = true;
    _setStatus(AppConnectionStatus.connecting);

    try {
      await client.connect(ip, port);

      // Check if already paired (by IP or known PC Name)
      if (pairing.isPairedWith(ip, _connectedPcName)) {
        _setStatus(AppConnectionStatus.authenticating);
        final authOk = await pairing.authenticate(client, ip, _connectedPcName);
        if (authOk) {
          _setStatus(AppConnectionStatus.connected);
          return;
        } else {
          // Token revoked or expired; require re-pairing
          await pairing.forgetDevice(ip, _connectedPcName);
        }
      }

      // Not paired or token revoked -> initiate pairing on PC
      final pairOk = await pairing.initiatePairing(client, 'Android Remote');
      if (pairOk) {
        _setStatus(AppConnectionStatus.pairingRequired);
      } else {
        _setStatus(AppConnectionStatus.error, 'PC declined pairing request.');
      }
    } catch (e) {
      _setStatus(AppConnectionStatus.error, 'Failed to connect to $ip: $e');
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _restoreSessionAfterReconnect() async {
    final ip = _activeIp;
    if (!_automaticReconnectEnabled ||
        _isConnecting ||
        _isRestoringSession ||
        ip == null) {
      return;
    }

    _isRestoringSession = true;
    try {
      if (pairing.isPairedWith(ip, _connectedPcName)) {
        _setStatus(AppConnectionStatus.authenticating);
        if (await pairing.authenticate(client, ip, _connectedPcName)) {
          _setStatus(AppConnectionStatus.connected);
          return;
        } else {
          await pairing.forgetDevice(ip, _connectedPcName);
        }
      }

      // Not paired or auth token failed: request pairing PIN
      final pairOk = await pairing.initiatePairing(client, 'Android Remote');
      if (pairOk) {
        _setStatus(AppConnectionStatus.pairingRequired);
      }
    } catch (_) {
    } finally {
      _isRestoringSession = false;
    }
  }

  Future<void> _connectToMostRecentPairedPc() async {
    if (!_automaticReconnectEnabled || _isConnecting || pairing.pairedPcs.isEmpty) return;

    final pairedPcs = List<PairedDeviceInfo>.from(pairing.pairedPcs)
      ..sort((a, b) => b.pairedAt.compareTo(a.pairedAt));
    final pc = pairedPcs.first;
    await connectToPC(pc.ip, 51234, pc.pcName);
  }

  void _reconnectToDiscoveredPairedPc(List<DiscoveredPC> discoveredPcs) {
    if (!_automaticReconnectEnabled || _isConnecting || isConnected) return;

    for (final pc in discoveredPcs) {
      final isPairedPc = pairing.isPairedWith(pc.ipAddress, pc.pcName);
      if (isPairedPc) {
        unawaited(connectToPC(pc.ipAddress, pc.port, pc.pcName));
        return;
      }
    }
  }

  /// Call this when the app becomes visible again. Android may suspend sockets
  /// while an app is in the background, so a fresh authenticated session is used.
  Future<void> reconnectOnResume() async {
    if (!_automaticReconnectEnabled) return;

    if (_activeIp == null) {
      await _connectToMostRecentPairedPc();
      return;
    }

    await client.reconnectNow(force: true);
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
    isPairingDialogShowing = false;
    _automaticReconnectEnabled = false;
    await client.disconnect();
    _setStatus(AppConnectionStatus.disconnected);
  }

  @visibleForTesting
  void setStatusForTesting(AppConnectionStatus s, [String? error]) {
    _setStatus(s, error);
  }

  void _onForegroundTaskAction(Object data) {
    if (data is Map && data.containsKey('action')) {
      final action = data['action'] as String;
      _handleNotificationAction(action);
    }
  }

  void _handleNotificationAction(String action) {
    if (!isConnected) return;
    switch (action) {
      case 'btn_prev':
        client.sendFastCommand(CommandTypes.mediaPrevious, {});
        break;
      case 'btn_play':
        client.sendFastCommand(CommandTypes.mediaPlayPause, {});
        break;
      case 'btn_next':
        client.sendFastCommand(CommandTypes.mediaNext, {});
        break;
      case 'btn_vol_up':
        client.sendFastCommand(CommandTypes.mediaVolumeUp, {});
        break;
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onForegroundTaskAction);
    _clientStateSub?.cancel();
    _discoverySub?.cancel();
    client.dispose();
    discovery.dispose();
    unawaited(RemoteForegroundService.stopService());
    super.dispose();
  }
}
