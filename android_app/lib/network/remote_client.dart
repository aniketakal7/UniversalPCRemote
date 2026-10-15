import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/constants.dart';
import '../protocol/models.dart';

enum ClientConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class RemoteClient {
  WebSocket? _socket;
  ClientConnectionState _state = ClientConnectionState.disconnected;
  String? _currentHost;
  int _currentPort = AppConstants.defaultServerPort;

  final Map<String, Completer<ResponseEnvelope>> _pendingRequests = {};
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;
  bool _isConnecting = false;
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;

  final StreamController<ClientConnectionState> _stateController =
      StreamController<ClientConnectionState>.broadcast();
  Stream<ClientConnectionState> get stateStream => _stateController.stream;
  ClientConnectionState get state => _state;

  String? get currentHost => _currentHost;
  int get currentPort => _currentPort;

  void _setState(ClientConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  Future<void> connect(String host,
      [int port = AppConstants.defaultServerPort]) async {
    if (_isConnecting) return;

    _isConnecting = true;
    // Normalize host and port
    String cleanHost = host.trim();
    int cleanPort = port;

    if (cleanHost.startsWith('ws://')) {
      cleanHost = cleanHost.substring(5);
    } else if (cleanHost.startsWith('wss://')) {
      cleanHost = cleanHost.substring(6);
    } else if (cleanHost.startsWith('http://')) {
      cleanHost = cleanHost.substring(7);
    } else if (cleanHost.startsWith('https://')) {
      cleanHost = cleanHost.substring(8);
    }

    if (cleanHost.contains('/')) {
      cleanHost = cleanHost.split('/').first;
    }

    if (cleanHost.contains(':') && !cleanHost.contains(']')) {
      final parts = cleanHost.split(':');
      if (parts.length == 2 && int.tryParse(parts[1]) != null) {
        cleanHost = parts[0];
        cleanPort = int.parse(parts[1]);
      }
    }

    _currentHost = cleanHost;
    _currentPort = cleanPort;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final generation = ++_connectionGeneration;
    _pingTimer?.cancel();
    _rejectPendingRequests('Connection replaced');
    await _closeCurrentSocket();

    _setState(ClientConnectionState.connecting);

    try {
      final uriString = cleanHost.contains(':') && !cleanHost.startsWith('[')
          ? 'ws://[$cleanHost]:$cleanPort/remote'
          : 'ws://$cleanHost:$cleanPort/remote';
      final uri = Uri.parse(uriString);
      final socket = await WebSocket.connect(uri.toString())
          .timeout(AppConstants.requestTimeout);
      if (generation != _connectionGeneration || _intentionalDisconnect) {
        await socket.close(WebSocketStatus.normalClosure);
        return;
      }

      _socket = socket;
      _reconnectAttempt = 0;

      _setState(ClientConnectionState.connected);
      _startHeartbeat(generation);

      socket.listen(
        _onMessageReceived,
        onError: (error) => _onError(generation, error),
        onDone: () => _onDone(generation),
        cancelOnError: true,
      );
    } catch (e) {
      if (generation == _connectionGeneration && !_intentionalDisconnect) {
        _setState(ClientConnectionState.error);
        _scheduleReconnect();
      }
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    ++_connectionGeneration;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _rejectPendingRequests('Connection closed');

    await _closeCurrentSocket();

    _setState(ClientConnectionState.disconnected);
  }

  void _rejectPendingRequests(String reason) {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(reason);
      }
    }
    _pendingRequests.clear();
  }

  Future<ResponseEnvelope> sendCommand(
    String type, [
    Map<String, dynamic> payload = const {},
    Duration timeout = AppConstants.requestTimeout,
  ]) async {
    if (_state != ClientConnectionState.connected || _socket == null) {
      throw Exception('Not connected to companion server.');
    }

    final requestId = CommandEnvelope.generateId();
    final envelope = CommandEnvelope(
      version: AppConstants.protocolVersion,
      requestId: requestId,
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      payload: payload,
    );

    final completer = Completer<ResponseEnvelope>();
    _pendingRequests[requestId] = completer;

    try {
      _socket!.add(envelope.encode());
    } catch (e) {
      _pendingRequests.remove(requestId);
      throw Exception('Failed to send command over socket: $e');
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw TimeoutException(
            'Command "$type" timed out after ${timeout.inSeconds}s');
      },
    );
  }

  void sendFastCommand(String type, Map<String, dynamic> payload) {
    if (_state != ClientConnectionState.connected || _socket == null) return;

    try {
      final envelope = CommandEnvelope(
        version: AppConstants.protocolVersion,
        requestId: CommandEnvelope.generateFastId(),
        type: type,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        // The server still returns errors, but successful high-frequency input
        // packets do not need an acknowledgement frame.
        payload: {...payload, '_noResponse': true},
      );
      _socket!.add(envelope.encode());
    } catch (_) {
      // Fast fire-and-forget skips error throwing
    }
  }

  void _onMessageReceived(dynamic data) {
    if (data is! String) return;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final response = ResponseEnvelope.fromJson(json);

      if (_pendingRequests.containsKey(response.requestId)) {
        final completer = _pendingRequests.remove(response.requestId);
        completer?.complete(response);
      }
    } catch (_) {
      // Ignore unparseable frames
    }
  }

  void _onError(int generation, dynamic error) {
    if (generation != _connectionGeneration) return;
    _setState(ClientConnectionState.error);
    _cleanupSocket();
    _scheduleReconnect();
  }

  void _onDone(int generation) {
    if (generation != _connectionGeneration) return;
    _cleanupSocket();
    if (!_intentionalDisconnect) {
      _setState(ClientConnectionState.disconnected);
      _scheduleReconnect();
    } else {
      _setState(ClientConnectionState.disconnected);
    }
  }

  void _cleanupSocket() {
    _pingTimer?.cancel();
    _socket = null;
    _rejectPendingRequests('Socket disconnected');
  }

  Future<void> _closeCurrentSocket() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        await socket.close(WebSocketStatus.normalClosure);
      } catch (_) {}
    }
  }

  int _consecutivePingFailures = 0;

  void _startHeartbeat(int generation) {
    _pingTimer?.cancel();
    _consecutivePingFailures = 0;
    _pingTimer = Timer.periodic(AppConstants.pingInterval, (_) async {
      if (generation == _connectionGeneration &&
          _state == ClientConnectionState.connected) {
        try {
          await sendCommand(
              CommandTypes.sessionPing, {}, const Duration(seconds: 7));
          _consecutivePingFailures = 0;
        } catch (_) {
          if (generation != _connectionGeneration) return;
          _consecutivePingFailures++;
          if (_consecutivePingFailures >= 2) {
            // 2 consecutive heartbeat timeouts -> trigger reconnect
            ++_connectionGeneration;
            await _closeCurrentSocket();
            _cleanupSocket();
            _setState(ClientConnectionState.disconnected);
            _scheduleReconnect();
          }
        }
      }
    });
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _currentHost == null) return;
    if (_reconnectTimer != null) return;
    const delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 20),
      Duration(seconds: 30)
    ];
    final delayIndex = _reconnectAttempt.clamp(0, delays.length - 1);
    final delay = delays[delayIndex];
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      if (_state != ClientConnectionState.connected &&
          !_intentionalDisconnect) {
        _setState(ClientConnectionState.reconnecting);
        try {
          await connect(_currentHost!, _currentPort);
        } catch (_) {
          // Reconnect attempt failed; will trigger next schedule
        }
      }
    });
  }

  /// Re-establishes the socket after Android resumes from the background.
  /// Authentication is intentionally handled by ConnectionStateManager because
  /// each new socket has a new server-side session.
  Future<void> reconnectNow({bool force = false}) async {
    if (_currentHost == null || _intentionalDisconnect) return;
    if (!force && _state == ClientConnectionState.connected) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await connect(_currentHost!, _currentPort);
    } catch (_) {
      // The normal reconnect timer will keep retrying while the PC is unavailable.
    }
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
