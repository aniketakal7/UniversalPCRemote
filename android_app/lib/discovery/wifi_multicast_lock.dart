import 'package:flutter/services.dart';

/// Keeps Wi-Fi multicast/broadcast reception available while discovery runs.
/// Android otherwise may filter UDP beacons to reduce battery consumption.
class WifiMulticastLock {
  static const _channel = MethodChannel('universal_pc_remote/wifi_multicast');

  static Future<void> acquire() async {
    try {
      await _channel.invokeMethod<void>('acquire');
    } on PlatformException {
      // Discovery can still work on devices where the platform service is not
      // available, so leave Manual IP connection usable.
    } on MissingPluginException {
      // Allows non-Android test environments to use the discovery service.
    }
  }

  static Future<void> release() async {
    try {
      await _channel.invokeMethod<void>('release');
    } on PlatformException {
      // Nothing to release.
    } on MissingPluginException {
      // Nothing to release in non-Android environments.
    }
  }
}
