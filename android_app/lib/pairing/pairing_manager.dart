import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/remote_client.dart';
import '../protocol/models.dart';

class PairedDeviceInfo {
  final String ip;
  final String pcName;
  final String authToken;
  final DateTime pairedAt;

  PairedDeviceInfo({
    required this.ip,
    required this.pcName,
    required this.authToken,
    required this.pairedAt,
  });

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'pcName': pcName,
        'authToken': authToken,
        'pairedAt': pairedAt.toIso8601String(),
      };

  factory PairedDeviceInfo.fromJson(Map<String, dynamic> json) => PairedDeviceInfo(
        ip: json['ip'] as String,
        pcName: json['pcName'] as String,
        authToken: json['authToken'] as String,
        pairedAt: DateTime.parse(json['pairedAt'] as String),
      );
}

class PairingManager {
  static const String _prefDeviceIdKey = 'upcr_device_id';
  static const String _prefPairedPcsKey = 'upcr_paired_pcs';

  String? _deviceId;
  final Map<String, PairedDeviceInfo> _pairedPcs = {};

  String get deviceId => _deviceId ?? 'phone-client';
  List<PairedDeviceInfo> get pairedPcs => _pairedPcs.values.toList();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_prefDeviceIdKey);
    if (_deviceId == null) {
      _deviceId = 'phone-${CommandEnvelope.generateId().substring(0, 8)}';
      await prefs.setString(_prefDeviceIdKey, _deviceId!);
    }

    final savedJson = prefs.getString(_prefPairedPcsKey);
    if (savedJson != null) {
      try {
        final list = (jsonDecode(savedJson) as List).cast<Map<String, dynamic>>();
        for (final item in list) {
          final info = PairedDeviceInfo.fromJson(item);
          _pairedPcs[info.ip] = info;
        }
      } catch (_) {}
    }
  }

  bool isPairedWith(String ip) => _pairedPcs.containsKey(ip);

  String? getAuthTokenFor(String ip) => _pairedPcs[ip]?.authToken;

  Future<bool> initiatePairing(RemoteClient client, String deviceName) async {
    final resp = await client.sendCommand(
      CommandTypes.authPairRequest,
      {
        'deviceId': deviceId,
        'deviceName': deviceName,
      },
    );
    return resp.success;
  }

  Future<bool> verifyPairing(RemoteClient client, String ip, String pin) async {
    final resp = await client.sendCommand(
      CommandTypes.authPairVerify,
      {
        'deviceId': deviceId,
        'pin': pin.trim(),
      },
    );

    if (resp.success && resp.data != null) {
      final token = resp.data['authToken'] as String?;
      final pcName = resp.data['pcName'] as String? ?? 'Windows PC';

      if (token != null) {
        final info = PairedDeviceInfo(
          ip: ip,
          pcName: pcName,
          authToken: token,
          pairedAt: DateTime.now(),
        );
        _pairedPcs[ip] = info;
        await _savePairedPcs();
        return true;
      }
    }
    return false;
  }

  Future<bool> authenticate(RemoteClient client, String ip) async {
    final token = getAuthTokenFor(ip);
    if (token == null) return false;

    try {
      final resp = await client.sendCommand(
        CommandTypes.authAuthenticate,
        {
          'deviceId': deviceId,
          'authToken': token,
        },
      );
      return resp.success;
    } catch (_) {
      return false;
    }
  }

  Future<void> forgetDevice(String ip) async {
    _pairedPcs.remove(ip);
    await _savePairedPcs();
  }

  Future<void> _savePairedPcs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _pairedPcs.values.map((v) => v.toJson()).toList();
    await prefs.setString(_prefPairedPcsKey, jsonEncode(jsonList));
  }
}
