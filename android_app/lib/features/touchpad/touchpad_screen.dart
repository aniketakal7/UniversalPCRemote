import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';

class TouchpadScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const TouchpadScreen({super.key, required this.stateManager});

  @override
  State<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends State<TouchpadScreen> {
  bool _isDragging = false;
  int _pointerCount = 0;
  Offset _lastPanOffset = Offset.zero;

  void _sendMove(double dx, double dy) {
    if (!widget.stateManager.isConnected) return;
    final sensitivity = widget.stateManager.mouseSensitivity;
    widget.stateManager.client.sendFastCommand(
      CommandTypes.mouseMove,
      {
        'dx': dx * sensitivity,
        'dy': dy * sensitivity,
        'sensitivity': 1.0,
      },
    );
  }

  void _sendClick(String button, [int clicks = 1]) {
    if (!widget.stateManager.isConnected) return;
    HapticFeedback.lightImpact();
    widget.stateManager.client.sendFastCommand(
      CommandTypes.mouseClick,
      {
        'button': button,
        'clicks': clicks,
      },
    );
  }

  void _sendScroll(double dx, double dy) {
    if (!widget.stateManager.isConnected) return;
    widget.stateManager.client.sendFastCommand(
      CommandTypes.mouseScroll,
      {
        'dx': dx * 0.05,
        'dy': dy * 0.05,
      },
    );
  }

  void _toggleDrag() {
    if (!widget.stateManager.isConnected) return;
    setState(() {
      _isDragging = !_isDragging;
    });
    HapticFeedback.mediumImpact();
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

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;

    return Column(
      children: [
        if (!isConnected)
          Container(
            color: Colors.amber.shade800,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: const Text(
              'Not connected to PC — Connect via Discovery tab',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),

        // Sensitivity Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              const Icon(Icons.speed, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              const Text('Sensitivity', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: widget.stateManager.mouseSensitivity,
                  min: 0.5,
                  max: 2.5,
                  divisions: 20,
                  label: widget.stateManager.mouseSensitivity.toStringAsFixed(1),
                  onChanged: (val) {
                    widget.stateManager.setSensitivity(val);
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  _isDragging ? Icons.pan_tool : Icons.pan_tool_outlined,
                  color: _isDragging ? Colors.red : Colors.grey,
                ),
                tooltip: _isDragging ? 'Release Drag' : 'Hold to Drag',
                onPressed: isConnected ? _toggleDrag : null,
              ),
            ],
          ),
        ),

        // Touchpad Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Listener(
              onPointerDown: (_) => setState(() => _pointerCount++),
              onPointerUp: (_) => setState(() => _pointerCount = (_pointerCount - 1).clamp(0, 5)),
              onPointerCancel: (_) => setState(() => _pointerCount = 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _sendClick('left'),
                onDoubleTap: () => _sendClick('left', 2),
                onLongPress: () => _sendClick('right'),
                onPanStart: (details) {
                  _lastPanOffset = details.localPosition;
                },
                onPanUpdate: (details) {
                  final dx = details.localPosition.dx - _lastPanOffset.dx;
                  final dy = details.localPosition.dy - _lastPanOffset.dy;
                  _lastPanOffset = details.localPosition;

                  if (_pointerCount >= 2) {
                    // Two finger scroll
                    _sendScroll(-dx, -dy);
                  } else {
                    _sendMove(dx, dy);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDragging
                          ? Colors.red
                          : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      width: _isDragging ? 2.0 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isDragging
                              ? 'DRAG MODE ACTIVE\nTap hand icon to release'
                              : 'Touchpad\n• Tap: Left Click  • Double Tap: Double Click\n• Two Fingers: Scroll  • Long Press: Right Click',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Mouse Physical Buttons (Left / Middle / Right)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isConnected ? () => _sendClick('left') : null,
                  child: const Text('LEFT CLICK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isConnected ? () => _sendClick('middle') : null,
                  child: const Icon(Icons.mouse),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isConnected ? () => _sendClick('right') : null,
                  child: const Text('RIGHT CLICK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
