import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HapticMode {
  smooth,   // Silky-smooth micro-tick (selectionClick) - subtle and refined
  standard, // Standard Android tactile impact (lightImpact)
  off,      // Completely disabled for silent operation
}

/// Centralized haptic feedback service designed for ultra-smooth,
/// non-jarring tactile responses with vibration rate-limiting.
class AppHaptics {
  static const String _prefKey = 'app_haptic_mode';
  static HapticMode _currentMode = HapticMode.smooth;
  static DateTime _lastHapticTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _minIntervalMs = 40; // Prevents motor rattle and continuous buzzing

  static HapticMode get currentMode => _currentMode;

  /// Initialize saved preference from local storage
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_prefKey);
      if (modeIndex != null && modeIndex >= 0 && modeIndex < HapticMode.values.length) {
        _currentMode = HapticMode.values[modeIndex];
      }
    } catch (_) {}
  }

  /// Change active haptic profile and persist
  static Future<void> setMode(HapticMode mode) async {
    _currentMode = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, mode.index);
    } catch (_) {}
  }

  /// Silky-smooth micro-click for mouse clicks, typing, media transport buttons.
  /// Uses selectionClick in smooth mode to avoid heavy motor overrun.
  static void click() {
    if (_currentMode == HapticMode.off) return;

    final now = DateTime.now();
    if (now.difference(_lastHapticTime).inMilliseconds < _minIntervalMs) {
      return;
    }
    _lastHapticTime = now;

    if (_currentMode == HapticMode.smooth) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Ultra-gentle selection tick for fine UI adjustments (sliders, toggles, menus)
  static void tick() {
    if (_currentMode == HapticMode.off) return;

    final now = DateTime.now();
    if (now.difference(_lastHapticTime).inMilliseconds < _minIntervalMs) return;
    _lastHapticTime = now;

    HapticFeedback.selectionClick();
  }

  /// Soft confirmation for macro triggers or action executions
  static void action() {
    if (_currentMode == HapticMode.off) return;

    final now = DateTime.now();
    if (now.difference(_lastHapticTime).inMilliseconds < _minIntervalMs) return;
    _lastHapticTime = now;

    if (_currentMode == HapticMode.smooth) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.mediumImpact();
    }
  }
}
