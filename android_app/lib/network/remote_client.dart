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

  Future<void> connect(String host, [int port = AppConstants.defaultServerPort]) async {
    _intentionalDisconnect = false;
    _currentHost = host;
    _currentPort = port;

    await disconnect();

    _setState(ClientConnectionState.connecting);

    try {
      final uri = Uri.parse('ws://$host:$port/remote');
      _socket = await WebSocket.connect(uri.toString())
          .timeout(AppConstants.requestTimeout);

      _setState(ClientConnectionState.connected);
      _startHeartbeat();

      _socket!.listen(
        _onMessageReceived,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
    } catch (e) {
      _setState(ClientConnectionState.error);
      _scheduleReconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    // Reject all pending requests
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Connection closed');
      }
    }
    _pendingRequests.clear();

    if (_socket != null) {
      try {
        await _socket!.close(WebSocketStatus.normalClosure);
      } catch (_) {}
      _socket = null;
    }

    _setState(ClientConnectionState.disconnected);
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
        throw TimeoutException('Command "$type" timed out after ${timeout.inSeconds}s');
      },
    );
  }

  void sendFastCommand(String type, Map<String, dynamic> payload) {
    if (_state != ClientConnectionState.connected || _socket == null) return;

    try {
      final envelope = CommandEnvelope(
        version: AppConstants.protocolVersion,
        requestId: CommandEnvelope.generateId(),
        type: type,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
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

  void _onError(dynamic error) {
    _setState(ClientConnectionState.error);
    _cleanupSocket();
    _scheduleReconnect();
  }

  void _onDone() {
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
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Socket disconnected');
      }
    }
    _pendingRequests.clear();
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConstants.pingInterval, (_) async {
      if (_state == ClientConnectionState.connected) {
        try {
          await sendCommand(CommandTypes.sessionPing, {}, const Duration(seconds: 4));
        } catch (_) {
          // Ping failed; trigger reconnect
          _cleanupSocket();
          _scheduleReconnect();
        }
      }
    });
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _currentHost == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_state != ClientConnectionState.connected && !_intentionalDisconnect) {
        _setState(ClientConnectionState.reconnecting);
        try {
          await connect(_currentHost!, _currentPort);
        } catch (_) {
          // Reconnect attempt failed; will trigger next schedule
        }
      }
    });
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
