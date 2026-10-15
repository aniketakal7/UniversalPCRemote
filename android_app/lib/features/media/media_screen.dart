import 'package:flutter/material.dart';
import '../../core/app_haptics.dart';
import '../../core/app_theme.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';
import '../../widgets/glass_card.dart';

class MediaScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const MediaScreen({super.key, required this.stateManager});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _sendMediaCommand(String type, [Map<String, dynamic> payload = const {}]) {
    if (!widget.stateManager.isConnected) return;
    AppHaptics.click();
    widget.stateManager.client.sendFastCommand(type, payload);
  }

  void _sendKey(String key) {
    if (!widget.stateManager.isConnected) return;
    AppHaptics.click();
    widget.stateManager.client.sendFastCommand(CommandTypes.keyboardKey, {'key': key});
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Audio Console Header
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final glowValue = _glowController.value;
              return Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primary.withOpacity(0.35 + glowValue * 0.15),
                      AppTheme.secondary.withOpacity(0.15 + glowValue * 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4 + glowValue * 0.25),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Media Transport Deck',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            isConnected
                ? 'Controlling active player on ${widget.stateManager.connectedPcName}'
                : 'Connect to PC to control playback & audio',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
          const SizedBox(height: 28),

          // Primary Playback Cluster (Hi-Fi Circular Array)
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Quick Seek 10s Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TactileButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      borderRadius: 14,
                      onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaSeekBackward) : null,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.replay_10_rounded, size: 20),
                          SizedBox(width: 6),
                          Text('10s', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    TactileButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      borderRadius: 14,
                      onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaSeekForward) : null,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('10s', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(width: 6),
                          Icon(Icons.forward_10_rounded, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Main Transport Controls (Previous, Play/Pause, Next)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous Track
                    TactileButton(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 22,
                      onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaPrevious) : null,
                      child: const Icon(Icons.skip_previous_rounded, size: 30),
                    ),
                    const SizedBox(width: 20),

                    // Main Glowing Play / Pause Button
                    TactileButton(
                      padding: const EdgeInsets.all(22),
                      borderRadius: 36,
                      gradient: AppTheme.primaryGradient,
                      onPressed: isConnected
                          ? () {
                              setState(() => _isPlaying = !_isPlaying);
                              _sendMediaCommand(CommandTypes.mediaPlayPause);
                            }
                          : null,
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Next Track
                    TactileButton(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 22,
                      onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaNext) : null,
                      child: const Icon(Icons.skip_next_rounded, size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stop & Fullscreen Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TactileButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      borderRadius: 12,
                      onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaStop) : null,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Stop', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TactileButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      borderRadius: 12,
                      onPressed: isConnected ? () => _sendKey('F11') : null,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen_rounded, size: 18),
                          SizedBox(width: 6),
                          Text('Fullscreen', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Master Volume Deck
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.volume_up_rounded, color: AppTheme.secondary, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Windows Master Audio',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    TactileButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      borderRadius: 12,
                      onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaVolumeMute) : null,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_off_rounded, size: 16, color: AppTheme.accentRose),
                          SizedBox(width: 6),
                          Text('Mute', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentRose)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Volume Up & Down Large Tactile Buttons
                Row(
                  children: [
                    Expanded(
                      child: TactileButton(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        borderRadius: 16,
                        onPressed: isConnected
                            ? () => _sendMediaCommand(CommandTypes.mediaVolumeDown, {'steps': 2})
                            : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volume_down_rounded, size: 22),
                            SizedBox(width: 8),
                            Text('Volume -', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TactileButton(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        borderRadius: 16,
                        gradient: AppTheme.purpleGradient,
                        onPressed: isConnected
                            ? () => _sendMediaCommand(CommandTypes.mediaVolumeUp, {'steps': 2})
                            : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volume_up_rounded, size: 22, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Volume +', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick Step Volume Presets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildVolumeStepChip('Small Step (-1)', () => _sendMediaCommand(CommandTypes.mediaVolumeDown, {'steps': 1}), isConnected),
                    _buildVolumeStepChip('Big Step (+5)', () => _sendMediaCommand(CommandTypes.mediaVolumeUp, {'steps': 5}), isConnected),
                    _buildVolumeStepChip('Mute Toggle', () => _sendMediaCommand(CommandTypes.mediaVolumeMute), isConnected),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Video & Player Hotkeys Card
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Video Player Hotkeys (YouTube, Netflix, VLC)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHotkeyChip('Space (Play/Pause)', 'SPACE', isConnected),
                    _buildHotkeyChip('F (Fullscreen)', 'F', isConnected),
                    _buildHotkeyChip('M (Mute)', 'M', isConnected),
                    _buildHotkeyChip('C (Subtitles)', 'C', isConnected),
                    _buildHotkeyChip('Esc (Exit Full)', 'ESCAPE', isConnected),
                    _buildHotkeyChip('J (Rewind 10s)', 'J', isConnected),
                    _buildHotkeyChip('L (Forward 10s)', 'L', isConnected),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeStepChip(String label, VoidCallback onTap, bool enabled) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: enabled ? AppTheme.primaryLight : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildHotkeyChip(String label, String key, bool enabled) {
    return TactileButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 12,
      onPressed: enabled ? () => _sendKey(key) : null,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
