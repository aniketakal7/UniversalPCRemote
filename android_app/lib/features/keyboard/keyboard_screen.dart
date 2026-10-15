import 'package:flutter/material.dart';
import '../../core/app_haptics.dart';
import '../../core/app_theme.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';
import '../../widgets/glass_card.dart';

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
    AppHaptics.click();
    widget.stateManager.client.sendFastCommand(
      CommandTypes.keyboardText,
      {'text': text},
    );
  }

  void _sendKey(String key) {
    if (!widget.stateManager.isConnected) return;
    AppHaptics.click();

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
    AppHaptics.action();
    widget.stateManager.client.sendFastCommand(
      CommandTypes.keyboardCombination,
      {
        'modifiers': mods,
        'key': key,
      },
    );
  }

  Widget _buildModButton(String label, bool active, VoidCallback onTap) {
    return TactileButton(
      isToggled: active,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 14,
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppTheme.accentGreen : Colors.grey.withOpacity(0.4),
              boxShadow: active
                  ? [const BoxShadow(color: AppTheme.accentGreen, blurRadius: 6, spreadRadius: 1)]
                  : [],
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildKeyButton(String label, String key, {int flex = 1, IconData? icon, Color? textColor}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: TactileButton(
          padding: const EdgeInsets.symmetric(vertical: 14),
          borderRadius: 12,
          onPressed: widget.stateManager.isConnected ? () => _sendKey(key) : null,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 20)
                : Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Streamlined Text Input Bar
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Type text here to send instantly to PC...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      suffixIcon: _textController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _textController.clear()),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (val) {
                      _sendText(val);
                      _textController.clear();
                      _focusNode.requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TactileButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  borderRadius: 14,
                  gradient: AppTheme.primaryGradient,
                  onPressed: isConnected && _textController.text.isNotEmpty
                      ? () {
                          _sendText(_textController.text);
                          _textController.clear();
                        }
                      : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Latching Modifiers Rack with Active LED Glows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildModButton('CTRL', _ctrlActive, () => setState(() => _ctrlActive = !_ctrlActive)),
              _buildModButton('ALT', _altActive, () => setState(() => _altActive = !_altActive)),
              _buildModButton('SHIFT', _shiftActive, () => setState(() => _shiftActive = !_shiftActive)),
              _buildModButton('WIN', _winActive, () => setState(() => _winActive = !_winActive)),
            ],
          ),
          const SizedBox(height: 16),

          // Core Editing & Function Keys Deck
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildKeyButton('ESC', 'ESCAPE', textColor: AppTheme.accentRose),
                    _buildKeyButton('TAB', 'TAB'),
                    _buildKeyButton('DEL', 'DELETE'),
                    _buildKeyButton('BACKSPACE', 'BACKSPACE', flex: 2, icon: Icons.backspace_outlined),
                  ],
                ),
                Row(
                  children: [
                    _buildKeyButton('SPACE BAR', 'SPACE', flex: 3),
                    _buildKeyButton('ENTER', 'ENTER', flex: 2, icon: Icons.keyboard_return_rounded, textColor: AppTheme.secondary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Directional Navigation Cluster (Ergonomic D-Pad)
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
              children: [
                Text(
                  'Directional Navigation',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 68),
                    SizedBox(
                      width: 68,
                      child: TactileButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        borderRadius: 14,
                        onPressed: isConnected ? () => _sendKey('UP') : null,
                        child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
                      ),
                    ),
                    const SizedBox(width: 68),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 68,
                      child: TactileButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        borderRadius: 14,
                        onPressed: isConnected ? () => _sendKey('LEFT') : null,
                        child: const Icon(Icons.keyboard_arrow_left_rounded, size: 24),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 68,
                      child: TactileButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        borderRadius: 14,
                        onPressed: isConnected ? () => _sendKey('DOWN') : null,
                        child: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 68,
                      child: TactileButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        borderRadius: 14,
                        onPressed: isConnected ? () => _sendKey('RIGHT') : null,
                        child: const Icon(Icons.keyboard_arrow_right_rounded, size: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Windows Power Shortcuts
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryLight, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Windows Power Shortcuts',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildShortcutPill('Ctrl+C', 'Copy', () => _sendShortcut(['ctrl'], 'C')),
                    _buildShortcutPill('Ctrl+V', 'Paste', () => _sendShortcut(['ctrl'], 'V')),
                    _buildShortcutPill('Ctrl+Z', 'Undo', () => _sendShortcut(['ctrl'], 'Z')),
                    _buildShortcutPill('Ctrl+A', 'Select All', () => _sendShortcut(['ctrl'], 'A')),
                    _buildShortcutPill('Alt+Tab', 'Switch App', () => _sendShortcut(['alt'], 'TAB')),
                    _buildShortcutPill('Win+D', 'Desktop', () => _sendShortcut(['win'], 'D')),
                    _buildShortcutPill('Win+E', 'Explorer', () => _sendShortcut(['win'], 'E')),
                    _buildShortcutPill('Win+V', 'Clipboard', () => _sendShortcut(['win'], 'V')),
                    _buildShortcutPill('Ctrl+Shift+Esc', 'Task Mgr', () => _sendShortcut(['ctrl', 'shift'], 'ESCAPE')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Function Keys Rack (F1–F12)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Function Keys Rack (F1 – F12)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: 12,
                  itemBuilder: (ctx, index) {
                    final fNum = index + 1;
                    return TactileButton(
                      padding: EdgeInsets.zero,
                      borderRadius: 10,
                      onPressed: isConnected ? () => _sendKey('F$fNum') : null,
                      child: Center(
                        child: Text(
                          'F$fNum',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutPill(String combo, String label, VoidCallback onTap) {
    return TactileButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 12,
      onPressed: widget.stateManager.isConnected ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(combo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryLight)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
