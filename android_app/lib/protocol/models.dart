import 'dart:convert';
import 'dart:math';

class CommandTypes {
  // Auth & Session
  static const String authPairRequest = 'auth.pair_request';
  static const String authPairVerify = 'auth.pair_verify';
  static const String authAuthenticate = 'auth.authenticate';
  static const String sessionPing = 'session.ping';
  static const String sessionPong = 'session.pong';

  // Mouse
  static const String mouseMove = 'mouse.move';
  static const String mouseClick = 'mouse.click';
  static const String mouseDown = 'mouse.down';
  static const String mouseUp = 'mouse.up';
  static const String mouseScroll = 'mouse.scroll';

  // Keyboard
  static const String keyboardText = 'keyboard.text';
  static const String keyboardKey = 'keyboard.key';
  static const String keyboardCombination = 'keyboard.combination';

  // Media
  static const String mediaPlayPause = 'media.play_pause';
  static const String mediaNext = 'media.next';
  static const String mediaPrevious = 'media.previous';
  static const String mediaStop = 'media.stop';
  static const String mediaSeekBackward = 'media.seek_backward';
  static const String mediaSeekForward = 'media.seek_forward';
  static const String mediaVolumeUp = 'media.volume_up';
  static const String mediaVolumeDown = 'media.volume_down';
  static const String mediaVolumeMute = 'media.volume_mute';
  static const String mediaGetStatus = 'media.get_status';

  // System
  static const String systemLock = 'system.lock';
  static const String systemSleep = 'system.sleep';
  static const String systemRestart = 'system.restart';
  static const String systemShutdown = 'system.shutdown';
  static const String systemCancelShutdown = 'system.cancel_shutdown';
  static const String systemGetInfo = 'system.get_info';

  // Clipboard
  static const String clipboardGet = 'clipboard.get';
  static const String clipboardSet = 'clipboard.set';

  // Remotes
  static const String remoteList = 'remote.list';
  static const String remoteExecute = 'remote.execute';

  // Macros
  static const String macroList = 'macro.list';
  static const String macroExecute = 'macro.execute';

  // Diagnostics
  static const String diagnosticsStatus = 'diagnostics.status';
}

class CommandEnvelope {
  final int version;
  final String requestId;
  final String type;
  final int timestamp;
  final Map<String, dynamic> payload;

  CommandEnvelope({
    this.version = 1,
    required this.requestId,
    required this.type,
    required this.timestamp,
    this.payload = const {},
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'requestId': requestId,
        'type': type,
        'timestamp': timestamp,
        'payload': payload,
      };

  String encode() => jsonEncode(toJson());

  /// Cryptographically secure UUID v4 — used for commands that expect a response.
  static String generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // Version 4
    values[8] = (values[8] & 0x3f) | 0x80; // Variant 10
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Fast monotonic counter-based ID — used for fire-and-forget input packets
  /// (mouse.move, mouse.scroll, media keys) where crypto-strength uniqueness
  /// is unnecessary. ~100x cheaper than generateId() on the hot path.
  static int _fastCounter = 0;
  static String generateFastId() => 'f${++_fastCounter}';
}

class ResponseEnvelope {
  final int version;
  final String requestId;
  final String type;
  final bool success;
  final dynamic data;
  final ErrorPayload? error;

  ResponseEnvelope({
    required this.version,
    required this.requestId,
    required this.type,
    required this.success,
    this.data,
    this.error,
  });

  factory ResponseEnvelope.fromJson(Map<String, dynamic> json) {
    return ResponseEnvelope(
      version: json['version'] as int? ?? 1,
      requestId: json['requestId'] as String? ?? '',
      type: json['type'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      data: json['data'],
      error: json['error'] != null
          ? ErrorPayload.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ErrorPayload {
  final String code;
  final String message;

  ErrorPayload({required this.code, required this.message});

  factory ErrorPayload.fromJson(Map<String, dynamic> json) {
    return ErrorPayload(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'An error occurred.',
    );
  }

  @override
  String toString() => '[$code] $message';
}
