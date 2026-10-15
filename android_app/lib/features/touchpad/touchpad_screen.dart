import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_haptics.dart';
import '../../core/app_theme.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';
import '../../widgets/glass_card.dart';

class TouchpadScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const TouchpadScreen({super.key, required this.stateManager});

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  bool _isDragging = false;
  int _pointerCount = 0;
  Offset _pendingMove = Offset.zero;
  Offset _pendingScroll = Offset.zero;
  DateTime? _lastMotionSentAt;
  Timer? _motionFlushTimer;

  // Touch visualization
  Offset? _activeTouchPos;
  bool _showTouchDot = false;

  // Multi-finger tracking and gesture detection
  final Map<int, Offset> _activePointers = {};
  final Map<int, Offset> _pointerStartPositions = {};
  int _maxPointersThisGesture = 0;
  DateTime? _gestureStartTime;
  bool _gestureActionTriggered = false;
  double _gestureCumulativeDx = 0;
  double _gestureCumulativeDy = 0;
  bool _twoFingerTapPossible = false;
  bool _threeFingerTapPossible = false;

  // Gesture HUD feedback overlay
  String? _gestureFeedbackText;
  IconData? _gestureFeedbackIcon;
  Timer? _feedbackTimer;

  static const _motionInterval = Duration(milliseconds: 8);

  // Throttle touch dot visual updates to ~30fps to avoid full widget rebuilds
  // on every pointer move. Motion data still flows at full rate.
  Timer? _touchDotThrottleTimer;
  static const _touchDotVisualInterval = Duration(milliseconds: 33);

  @override
  void dispose() {
    _motionFlushTimer?.cancel();
    _touchDotThrottleTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _triggerGestureFeedback(String text, IconData icon) {
    _feedbackTimer?.cancel();
    AppHaptics.action();
    if (mounted) {
      setState(() {
        _gestureFeedbackText = text;
        _gestureFeedbackIcon = icon;
      });
      _feedbackTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _gestureFeedbackText = null;
            _gestureFeedbackIcon = null;
          });
        }
      });
    }
  }

  void _queueMove(double dx, double dy) {
    _pendingMove += Offset(dx, dy);
    _scheduleMotionFlush();
  }

  void _queueScroll(double dx, double dy) {
    _pendingScroll += Offset(dx, dy);
    _scheduleMotionFlush();
  }

  void _scheduleMotionFlush() {
    final now = DateTime.now();
    final elapsed = _lastMotionSentAt == null ? _motionInterval : now.difference(_lastMotionSentAt!);
    if (elapsed >= _motionInterval) {
      _motionFlushTimer?.cancel();
      _motionFlushTimer = null;
      _flushPendingMotion();
      return;
    }

    _motionFlushTimer ??= Timer(_motionInterval - elapsed, () {
      _motionFlushTimer = null;
      _flushPendingMotion();
    });
  }

  void _flushPendingMotion() {
    if (!widget.stateManager.isConnected) {
      _pendingMove = Offset.zero;
      _pendingScroll = Offset.zero;
      return;
    }

    if (_pendingMove != Offset.zero) {
      final move = _pendingMove;
      _pendingMove = Offset.zero;
      widget.stateManager.client.sendFastCommand(
        CommandTypes.mouseMove,
        {
          'dx': move.dx,
          'dy': move.dy,
          'sensitivity': widget.stateManager.mouseSensitivity,
        },
      );
    }

    if (_pendingScroll != Offset.zero) {
      final scroll = _pendingScroll;
      _pendingScroll = Offset.zero;
      widget.stateManager.client.sendFastCommand(
        CommandTypes.mouseScroll,
        {'dx': scroll.dx * 0.05, 'dy': scroll.dy * 0.05},
      );
    }

    _lastMotionSentAt = DateTime.now();
  }

  void _sendClick(String button, [int clicks = 1]) {
    if (!widget.stateManager.isConnected) return;
    AppHaptics.click();
    widget.stateManager.client.sendFastCommand(
      CommandTypes.mouseClick,
      {
        'button': button,
        'clicks': clicks,
      },
    );
  }

  void _toggleDrag() {
    if (!widget.stateManager.isConnected) return;
    setState(() {
      _isDragging = !_isDragging;
    });
    AppHaptics.tick();
    if (_isDragging) {
      widget.stateManager.client.sendFastCommand(
        CommandTypes.mouseDown,
        {'button': 'left'},
      );
    } else {
      widget.stateManager.client.sendFastCommand(
        CommandTypes.mouseUp,
        {'button': 'left'},
      );
    }
  }

  void _sendShortcut(List<String> mods, String key) {
    if (!widget.stateManager.isConnected) return;
    AppHaptics.tick();
    widget.stateManager.client.sendFastCommand(
      CommandTypes.keyboardCombination,
      {
        'modifiers': mods,
        'key': key,
      },
    );
  }

  String _hapticModeLabel(HapticMode mode) {
    switch (mode) {
      case HapticMode.smooth:
        return 'Smooth';
      case HapticMode.standard:
        return 'Standard';
      case HapticMode.off:
        return 'Off';
    }
  }

  void _showSensitivitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final activeMode = widget.stateManager.hapticMode;

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardElevated : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sensitivity Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Touchpad Sensitivity',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.stateManager.mouseSensitivity.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pointer acceleration & speed curve',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SliderTheme(
                    data: SliderTheme.of(ctx).copyWith(
                      activeTrackColor: AppTheme.primary,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: widget.stateManager.mouseSensitivity,
                      min: 0.5,
                      max: 3.5,
                      divisions: 30,
                      label: '${widget.stateManager.mouseSensitivity.toStringAsFixed(1)}x',
                      onChanged: (val) {
                        setSheetState(() {});
                        setState(() {
                          widget.stateManager.setSensitivity(val);
                        });
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0.5x (Precision)', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                      Text('Default 1.4x', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                      Text('3.5x (Fast)', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                    ],
                  ),

                  const SizedBox(height: 22),
                  Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
                  const SizedBox(height: 18),

                  // Haptic Feedback Profile Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Vibration & Haptics',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          AppHaptics.click();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, size: 14, color: AppTheme.secondary),
                              SizedBox(width: 4),
                              Text('Test Feel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Smooth mode replaces harsh motor rumbles with silky micro-ticks',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      _buildHapticOption(
                        context: ctx,
                        title: 'Smooth',
                        subtitle: 'Silky tick',
                        icon: Icons.grain_rounded,
                        isSelected: activeMode == HapticMode.smooth,
                        onTap: () {
                          widget.stateManager.setHapticMode(HapticMode.smooth);
                          setSheetState(() {});
                          AppHaptics.click();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildHapticOption(
                        context: ctx,
                        title: 'Standard',
                        subtitle: 'Firm tap',
                        icon: Icons.vibration_rounded,
                        isSelected: activeMode == HapticMode.standard,
                        onTap: () {
                          widget.stateManager.setHapticMode(HapticMode.standard);
                          setSheetState(() {});
                          AppHaptics.click();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildHapticOption(
                        context: ctx,
                        title: 'Off',
                        subtitle: 'Silent',
                        icon: Icons.notifications_off_outlined,
                        isSelected: activeMode == HapticMode.off,
                        onTap: () {
                          widget.stateManager.setHapticMode(HapticMode.off);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHapticOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withOpacity(0.18)
                : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primaryLight : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? AppTheme.primaryLight : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGesturesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.touch_app_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Touchpad Shortcuts & Gestures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGestureRow(Icons.touch_app, '1-Finger Tap', 'Left Click'),
                _buildGestureRow(Icons.touch_app_outlined, '1-Finger Double Tap', 'Double Left Click'),
                _buildGestureRow(Icons.mouse_rounded, '2-Finger Tap', 'Right Click (Context Menu)'),
                _buildGestureRow(Icons.swipe_vertical, '2-Finger Drag', 'Vertical & Horizontal Scroll'),
                _buildGestureRow(Icons.search_rounded, '3-Finger Tap', 'Windows Search (Win+S)'),
                _buildGestureRow(Icons.arrow_upward_rounded, '3-Finger Swipe Up', 'Task View (Win+Tab)'),
                _buildGestureRow(Icons.arrow_downward_rounded, '3-Finger Swipe Down', 'Show Desktop (Win+D)'),
                _buildGestureRow(Icons.swap_horiz_rounded, '3-Finger Swipe Left / Right', 'Switch Active App (Alt+Tab)'),
                _buildGestureRow(Icons.space_dashboard_rounded, '4-Finger Swipe Left / Right', 'Switch Virtual Desktop'),
                _buildGestureRow(Icons.notifications_none_rounded, '4-Finger Swipe Up', 'Action Center (Win+A)'),
                _buildGestureRow(Icons.view_sidebar, 'Right Strip', 'One-Finger Quick Scroll'),
                _buildGestureRow(Icons.pan_tool, 'Drag Lock', 'Hold & Drag Mode for Windows'),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickShortcutDock(bool isDark, bool isConnected) {
    final shortcuts = [
      {'label': 'Esc', 'mods': <String>[], 'key': 'ESC', 'icon': Icons.close_rounded},
      {'label': 'Alt+Tab', 'mods': ['alt'], 'key': 'TAB', 'icon': Icons.swap_horiz_rounded},
      {'label': 'Win+E', 'mods': ['win'], 'key': 'E', 'icon': Icons.folder_open_rounded},
      {'label': 'Ctrl+Z', 'mods': ['ctrl'], 'key': 'Z', 'icon': Icons.undo_rounded},
      {'label': 'Ctrl+C', 'mods': ['ctrl'], 'key': 'C', 'icon': Icons.content_copy_rounded},
      {'label': 'Ctrl+V', 'mods': ['ctrl'], 'key': 'V', 'icon': Icons.content_paste_rounded},
      {'label': 'Task Mgr', 'mods': ['ctrl', 'shift'], 'key': 'ESC', 'icon': Icons.speed_rounded},
      {'label': 'Lock', 'mods': ['win'], 'key': 'L', 'icon': Icons.lock_outline_rounded},
    ];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final item = shortcuts[i];
          final mods = item['mods'] as List<String>;
          final key = item['key'] as String;
          final label = item['label'] as String;
          final icon = item['icon'] as IconData;

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isConnected
                ? () {
                    if (mods.isEmpty) {
                      widget.stateManager.client.sendFastCommand(CommandTypes.keyboardKey, {'key': key});
                    } else {
                      _sendShortcut(mods, key);
                    }
                    _triggerGestureFeedback('$label sent', icon);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardElevated : AppTheme.lightCardElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: AppTheme.primaryLight),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGestureRow(IconData icon, String gesture, String action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gesture, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(action, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (!isConnected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.accentRose.withOpacity(0.15),
              border: Border(bottom: BorderSide(color: AppTheme.accentRose.withOpacity(0.3))),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 16, color: AppTheme.accentRose),
                SizedBox(width: 8),
                Text(
                  'PC Disconnected — Tap top bar to connect',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentRose),
                ),
              ],
            ),
          ),

        // Quick Action & Precision Header Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              // Sensitivity pill
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showSensitivitySheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryLight),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.stateManager.mouseSensitivity.toStringAsFixed(1)}x • ${_hapticModeLabel(widget.stateManager.hapticMode)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Drag Mode Toggle Pill
              TactileButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                borderRadius: 14,
                isToggled: _isDragging,
                backgroundColor: _isDragging
                    ? AppTheme.accentRose.withOpacity(0.2)
                    : (isDark ? AppTheme.darkCardElevated : const Color(0xFFF1F5F9)),
                borderColor: _isDragging ? AppTheme.accentRose : null,
                onPressed: isConnected ? _toggleDrag : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isDragging ? Icons.pan_tool_rounded : Icons.pan_tool_outlined,
                      size: 15,
                      color: _isDragging ? AppTheme.accentRose : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isDragging ? 'Dragging ON' : 'Drag Lock',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isDragging ? AppTheme.accentRose : null,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Quick Desktop & Task View Shortcuts
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.desktop_windows_outlined, size: 20),
                tooltip: 'Show Desktop (Win+D)',
                onPressed: isConnected ? () => _sendShortcut(['win'], 'D') : null,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.tab_unselected_rounded, size: 20),
                tooltip: 'Task View (Win+Tab)',
                onPressed: isConnected ? () => _sendShortcut(['win'], 'TAB') : null,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.help_outline_rounded, size: 20),
                tooltip: 'Gestures Guide',
                onPressed: () => _showGesturesDialog(context),
              ),
            ],
          ),
        ),

        // Quick Touchpad Shortcut Dock (Instant 1-tap productivity keys)
        _buildQuickShortcutDock(isDark, isConnected),

        // Main Glassmorphic Precision Trackpad
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                // Primary Trackpad Surface
                Expanded(
                  child: Listener(
                    onPointerDown: (e) {
                      _activePointers[e.pointer] = e.localPosition;
                      _pointerStartPositions[e.pointer] = e.localPosition;

                      if (_activePointers.length > _maxPointersThisGesture) {
                        _maxPointersThisGesture = _activePointers.length;
                      }

                      if (_activePointers.length == 1) {
                        _gestureStartTime = DateTime.now();
                        _gestureActionTriggered = false;
                        _gestureCumulativeDx = 0;
                        _gestureCumulativeDy = 0;
                        _twoFingerTapPossible = false;
                        _threeFingerTapPossible = false;
                      } else if (_activePointers.length == 2 && !_gestureActionTriggered) {
                        _twoFingerTapPossible = true;
                        _gestureCumulativeDx = 0;
                        _gestureCumulativeDy = 0;
                      } else if (_activePointers.length == 3 && !_gestureActionTriggered) {
                        _twoFingerTapPossible = false;
                        _threeFingerTapPossible = true;
                        _gestureCumulativeDx = 0;
                        _gestureCumulativeDy = 0;
                      } else {
                        _twoFingerTapPossible = false;
                        _threeFingerTapPossible = false;
                      }

                      setState(() {
                        _pointerCount = _activePointers.length;
                        _showTouchDot = true;
                        _activeTouchPos = e.localPosition;
                      });
                    },
                    onPointerMove: (e) {
                      _activeTouchPos = e.localPosition;
                      if (_showTouchDot && _touchDotThrottleTimer == null) {
                        _touchDotThrottleTimer = Timer(_touchDotVisualInterval, () {
                          _touchDotThrottleTimer = null;
                          if (mounted && _showTouchDot) {
                            setState(() {});
                          }
                        });
                      }

                      _activePointers[e.pointer] = e.localPosition;

                      if (_activePointers.length == 1) {
                        // 1-finger cursor movement
                        if (!_gestureActionTriggered) {
                          _queueMove(e.delta.dx, e.delta.dy);
                        }
                      } else if (_activePointers.length == 2) {
                        final start = _pointerStartPositions[e.pointer] ?? e.localPosition;
                        if ((e.localPosition - start).distance > 16) {
                          _twoFingerTapPossible = false;
                        }
                        // 2-finger scroll
                        if (!_gestureActionTriggered) {
                          _queueScroll(-e.delta.dx, -e.delta.dy);
                        }
                      } else if (_activePointers.length == 3) {
                        _gestureCumulativeDx += e.delta.dx / 3.0;
                        _gestureCumulativeDy += e.delta.dy / 3.0;
                        final start = _pointerStartPositions[e.pointer] ?? e.localPosition;
                        if ((e.localPosition - start).distance > 16) {
                          _threeFingerTapPossible = false;
                        }

                        if (!_gestureActionTriggered) {
                          const threshold = 36.0;
                          if (_gestureCumulativeDy < -threshold && _gestureCumulativeDy.abs() > _gestureCumulativeDx.abs() * 1.1) {
                            // 3-Finger Swipe UP -> Task View
                            _gestureActionTriggered = true;
                            _threeFingerTapPossible = false;
                            _sendShortcut(['win'], 'TAB');
                            _triggerGestureFeedback('Task View (Win+Tab)', Icons.tab_unselected_rounded);
                          } else if (_gestureCumulativeDy > threshold && _gestureCumulativeDy.abs() > _gestureCumulativeDx.abs() * 1.1) {
                            // 3-Finger Swipe DOWN -> Show Desktop
                            _gestureActionTriggered = true;
                            _threeFingerTapPossible = false;
                            _sendShortcut(['win'], 'D');
                            _triggerGestureFeedback('Show Desktop (Win+D)', Icons.desktop_windows_outlined);
                          } else if (_gestureCumulativeDx > threshold && _gestureCumulativeDx.abs() > _gestureCumulativeDy.abs() * 1.1) {
                            // 3-Finger Swipe RIGHT -> Next App
                            _gestureActionTriggered = true;
                            _threeFingerTapPossible = false;
                            _sendShortcut(['alt'], 'TAB');
                            _triggerGestureFeedback('Next App (Alt+Tab)', Icons.swap_horiz_rounded);
                          } else if (_gestureCumulativeDx < -threshold && _gestureCumulativeDx.abs() > _gestureCumulativeDy.abs() * 1.1) {
                            // 3-Finger Swipe LEFT -> Prev App
                            _gestureActionTriggered = true;
                            _threeFingerTapPossible = false;
                            _sendShortcut(['alt', 'shift'], 'TAB');
                            _triggerGestureFeedback('Previous App', Icons.swap_horiz_rounded);
                          }
                        }
                      } else if (_activePointers.length == 4) {
                        _gestureCumulativeDx += e.delta.dx / 4.0;
                        _gestureCumulativeDy += e.delta.dy / 4.0;

                        if (!_gestureActionTriggered) {
                          const threshold = 40.0;
                          if (_gestureCumulativeDx > threshold) {
                            _gestureActionTriggered = true;
                            _sendShortcut(['ctrl', 'win'], 'RIGHT');
                            _triggerGestureFeedback('Next Desktop (Ctrl+Win+→)', Icons.arrow_forward_rounded);
                          } else if (_gestureCumulativeDx < -threshold) {
                            _gestureActionTriggered = true;
                            _sendShortcut(['ctrl', 'win'], 'LEFT');
                            _triggerGestureFeedback('Previous Desktop (Ctrl+Win+←)', Icons.arrow_back_rounded);
                          } else if (_gestureCumulativeDy < -threshold) {
                            _gestureActionTriggered = true;
                            _sendShortcut(['win'], 'A');
                            _triggerGestureFeedback('Action Center (Win+A)', Icons.notifications_none_rounded);
                          }
                        }
                      }
                    },
                    onPointerUp: (e) {
                      final duration = _gestureStartTime != null ? DateTime.now().difference(_gestureStartTime!) : Duration.zero;

                      if (!_gestureActionTriggered) {
                        if (_maxPointersThisGesture == 2 && _twoFingerTapPossible && duration < const Duration(milliseconds: 320)) {
                          _gestureActionTriggered = true;
                          _sendClick('right');
                          _triggerGestureFeedback('Right Click (2-Finger Tap)', Icons.mouse_rounded);
                        } else if (_maxPointersThisGesture == 3 && _threeFingerTapPossible && duration < const Duration(milliseconds: 320)) {
                          _gestureActionTriggered = true;
                          _sendShortcut(['win'], 'S');
                          _triggerGestureFeedback('Search (3-Finger Tap)', Icons.search_rounded);
                        }
                      }

                      _activePointers.remove(e.pointer);
                      _pointerStartPositions.remove(e.pointer);

                      setState(() {
                        _pointerCount = _activePointers.length;
                        if (_pointerCount == 0) {
                          _showTouchDot = false;
                          _maxPointersThisGesture = 0;
                          _gestureActionTriggered = false;
                          _twoFingerTapPossible = false;
                          _threeFingerTapPossible = false;
                          _motionFlushTimer?.cancel();
                          _motionFlushTimer = null;
                          _flushPendingMotion();
                        }
                      });
                    },
                    onPointerCancel: (_) {
                      _activePointers.clear();
                      _pointerStartPositions.clear();
                      setState(() {
                        _pointerCount = 0;
                        _showTouchDot = false;
                        _maxPointersThisGesture = 0;
                        _gestureActionTriggered = false;
                        _twoFingerTapPossible = false;
                        _threeFingerTapPossible = false;
                      });
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_maxPointersThisGesture <= 1 && !_gestureActionTriggered) {
                          _sendClick('left');
                        }
                      },
                      onDoubleTap: () {
                        if (_maxPointersThisGesture <= 1 && !_gestureActionTriggered) {
                          _sendClick('left', 2);
                        }
                      },
                      onLongPress: () {
                        if (_maxPointersThisGesture <= 1 && !_gestureActionTriggered) {
                          _sendClick('right');
                        }
                      },
                      onPanUpdate: (details) {
                        if (_pointerCount >= 2) {
                          // Two-finger scroll
                          _queueScroll(-details.delta.dx, -details.delta.dy);
                        } else {
                          // Single-finger cursor movement
                          _queueMove(details.delta.dx, details.delta.dy);
                        }
                      },
                      onPanEnd: (_) {
                        _motionFlushTimer?.cancel();
                        _motionFlushTimer = null;
                        _flushPendingMotion();
                      },
                      onPanCancel: () {
                        _motionFlushTimer?.cancel();
                        _motionFlushTimer = null;
                        _flushPendingMotion();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    AppTheme.darkCard,
                                    AppTheme.darkSurface,
                                  ]
                                : [
                                    Colors.white,
                                    AppTheme.lightCardElevated,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isDragging
                                ? AppTheme.accentRose
                                : (isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder),
                            width: _isDragging ? 2.0 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Subtle Corner Guides (Precision Aesthetics)
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: (isDark ? Colors.white10 : Colors.black12), width: 2),
                                    left: BorderSide(color: (isDark ? Colors.white10 : Colors.black12), width: 2),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: (isDark ? Colors.white10 : Colors.black12), width: 2),
                                    right: BorderSide(color: (isDark ? Colors.white10 : Colors.black12), width: 2),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 14,
                              left: 14,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: (isDark ? Colors.white10 : Colors.black12), width: 2),
                                    left: BorderSide(color: (isDark ? Colors.white10 : Colors.black12), width: 2),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 14,
                              right: 14,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: (isDark ? Colors.white10 : Colors.black12), width: 2),
                                    right: BorderSide(color: (isDark ? Colors.white10 : Colors.black12), width: 2),
                                  ),
                                ),
                              ),
                            ),

                            // Center Trackpad Watermark / Status
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isDragging ? Icons.pan_tool_rounded : Icons.gesture_rounded,
                                    size: 40,
                                    color: _isDragging
                                        ? AppTheme.accentRose.withOpacity(0.6)
                                        : (isDark ? Colors.white12 : Colors.black12),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _isDragging
                                        ? 'DRAG LOCK ENGAGED\nTouch to move selected window or file'
                                        : 'Precision Glass Surface',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: _isDragging
                                          ? AppTheme.accentRose
                                          : (isDark ? Colors.white24 : Colors.black26),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Live Touch Glow Dot
                            if (_showTouchDot && _activeTouchPos != null)
                              Positioned(
                                left: _activeTouchPos!.dx - 22,
                                top: _activeTouchPos!.dy - 22,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.primary.withOpacity(0.2),
                                      border: Border.all(color: AppTheme.primaryLight.withOpacity(0.5), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),

                            // Live Gesture HUD Feedback Overlay
                            if (_gestureFeedbackText != null)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppTheme.darkSurface : Colors.white).withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppTheme.primary, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.25),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_gestureFeedbackIcon, color: AppTheme.primaryLight, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _gestureFeedbackText!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Dedicated Vertical Scroll Strip (1-finger glide)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    _queueScroll(0, -details.delta.dy * 2.5);
                  },
                  child: Container(
                    width: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                AppTheme.darkCard,
                                AppTheme.darkCardElevated,
                                AppTheme.darkCard,
                              ]
                            : [
                                AppTheme.lightCardElevated,
                                AppTheme.lightCardBorder,
                                AppTheme.lightCardElevated,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_drop_up_rounded, size: 20, color: Colors.grey),
                        const SizedBox(height: 12),
                        // Texture notches
                        ...List.generate(6, (i) => Container(
                          width: 14,
                          height: 2,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black26,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        )),
                        const SizedBox(height: 12),
                        const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tactile Physical Mouse Buttons Deck
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Row(
            children: [
              // Left Click Button
              Expanded(
                flex: 4,
                child: TactileButton(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  borderRadius: 18,
                  onPressed: isConnected ? () => _sendClick('left') : null,
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mouse_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'LEFT CLICK',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Middle Click (Scroll Wheel) Button
              Expanded(
                flex: 2,
                child: TactileButton(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  borderRadius: 18,
                  onPressed: isConnected ? () => _sendClick('middle') : null,
                  child: const Center(
                    child: Icon(Icons.fiber_manual_record_rounded, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Right Click Button
              Expanded(
                flex: 4,
                child: TactileButton(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  borderRadius: 18,
                  onPressed: isConnected ? () => _sendClick('right') : null,
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RIGHT CLICK',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.more_vert_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
