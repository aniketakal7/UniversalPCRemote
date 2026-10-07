import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';

class KeyboardScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const KeyboardScreen({super.key, required this.stateManager});

  @override
  State<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends State<KeyboardScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _ctrlActive = false;
  bool _altActive = false;
  bool _shiftActive = false;
  bool _winActive = false;

  void _sendText(String text) {
    if (!widget.stateManager.isConnected || text.isEmpty) return;
    widget.stateManager.client.sendFastCommand(
      CommandTypes.keyboardText,
      {'text': text},
    );
  }

  void _sendKey(String key) {
    if (!widget.stateManager.isConnected) return;
    HapticFeedback.lightImpact();

    final activeMods = <String>[];
    if (_ctrlActive) activeMods.add('ctrl');
    if (_altActive) activeMods.add('alt');
    if (_shiftActive) activeMods.add('shift');
    if (_winActive) activeMods.add('win');

    if (activeMods.isNotEmpty) {
      widget.stateManager.client.sendFastCommand(
        CommandTypes.keyboardCombination,
        {
          'modifiers': activeMods,
          'key': key,
        },
      );

      // Auto un-toggle modifiers after combination
      setState(() {
        _ctrlActive = false;
        _altActive = false;
        _shiftActive = false;
        _winActive = false;
      });
    } else {
      widget.stateManager.client.sendFastCommand(
        CommandTypes.keyboardKey,
        {'key': key},
      );
    }
  }

  void _sendShortcut(List<String> mods, String key) {
    if (!widget.stateManager.isConnected) return;
    HapticFeedback.mediumImpact();
    widget.stateManager.client.sendFastCommand(
      CommandTypes.keyboardCombination,
      {
        'modifiers': mods,
        'key': key,
      },
    );
  }

  Widget _buildModButton(String label, bool active, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildKeyButton(String label, String key, {int flex = 1, IconData? icon}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: widget.stateManager.isConnected ? () => _sendKey(key) : null,
          child: icon != null
              ? Icon(icon, size: 18)
              : Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Text Input Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Type text here to send to PC...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (val) {
                        _sendText(val);
                        _textController.clear();
                        _focusNode.requestFocus();
                      },
                    ),
                  ),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: isConnected
                        ? () {
                            if (_textController.text.isNotEmpty) {
                              _sendText(_textController.text);
                              _textController.clear();
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Modifiers Row
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _buildModButton('CTRL', _ctrlActive, () => setState(() => _ctrlActive = !_ctrlActive)),
              _buildModButton('ALT', _altActive, () => setState(() => _altActive = !_altActive)),
              _buildModButton('SHIFT', _shiftActive, () => setState(() => _shiftActive = !_shiftActive)),
              _buildModButton('WIN', _winActive, () => setState(() => _winActive = !_winActive)),
            ],
          ),
          const SizedBox(height: 12),

          // Common Windows Shortcuts
          Text(
            'Quick Shortcuts',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(label: const Text('Ctrl + C (Copy)'), onPressed: () => _sendShortcut(['ctrl'], 'C')),
              ActionChip(label: const Text('Ctrl + V (Paste)'), onPressed: () => _sendShortcut(['ctrl'], 'V')),
              ActionChip(label: const Text('Ctrl + Z (Undo)'), onPressed: () => _sendShortcut(['ctrl'], 'Z')),
              ActionChip(label: const Text('Ctrl + A (All)'), onPressed: () => _sendShortcut(['ctrl'], 'A')),
              ActionChip(label: const Text('Alt + Tab'), onPressed: () => _sendShortcut(['alt'], 'TAB')),
              ActionChip(label: const Text('Win + D (Desktop)'), onPressed: () => _sendShortcut(['win'], 'D')),
              ActionChip(label: const Text('Ctrl + Shift + Esc'), onPressed: () => _sendShortcut(['ctrl', 'shift'], 'ESCAPE')),
            ],
          ),
          const SizedBox(height: 16),

          // Navigation & Editing Keys
          Text(
            'Navigation & Control',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildKeyButton('ESC', 'ESCAPE'),
              _buildKeyButton('TAB', 'TAB'),
              _buildKeyButton('DEL', 'DELETE'),
              _buildKeyButton('BACK', 'BACKSPACE', flex: 2, icon: Icons.backspace_outlined),
            ],
          ),
          Row(
            children: [
              _buildKeyButton('SPACE', 'SPACE', flex: 3),
              _buildKeyButton('ENTER', 'ENTER', flex: 2, icon: Icons.keyboard_return),
            ],
          ),
          const SizedBox(height: 8),

          // Arrow Keys
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 50),
              _buildKeyButton('▲', 'UP', icon: Icons.arrow_upward),
              const SizedBox(width: 50),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKeyButton('◀', 'LEFT', icon: Icons.arrow_back),
              _buildKeyButton('▼', 'DOWN', icon: Icons.arrow_downward),
              _buildKeyButton('▶', 'RIGHT', icon: Icons.arrow_forward),
            ],
          ),
          const SizedBox(height: 16),

          // Function Keys Row
          Text(
            'Function Keys',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(12, (index) {
              final fNum = index + 1;
              return SizedBox(
                width: 54,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: isConnected ? () => _sendKey('F$fNum') : null,
                  child: Text('F$fNum', style: const TextStyle(fontSize: 11)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
