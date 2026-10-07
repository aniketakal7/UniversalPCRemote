import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';

class MediaScreen extends StatelessWidget {
  final ConnectionStateManager stateManager;

  const MediaScreen({super.key, required this.stateManager});

  void _sendMediaCommand(String type, [Map<String, dynamic> payload = const {}]) {
    if (!stateManager.isConnected) return;
    HapticFeedback.lightImpact();
    stateManager.client.sendFastCommand(type, payload);
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = stateManager.isConnected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Media Header Art / Icon
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
            ),
            child: Icon(
              Icons.music_note,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Windows Media Controller',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Controls Spotify, YouTube, VLC, and Windows Media',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 36),

          // Transport Controls (Prev, Play/Pause, Next)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                iconSize: 36,
                icon: const Icon(Icons.skip_previous),
                onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaPrevious) : null,
              ),
              const SizedBox(width: 24),
              IconButton.filled(
                iconSize: 52,
                icon: const Icon(Icons.play_arrow),
                onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaPlayPause) : null,
              ),
              const SizedBox(width: 24),
              IconButton.filledTonal(
                iconSize: 36,
                icon: const Icon(Icons.skip_next),
                onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaNext) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          IconButton.outlined(
            icon: const Icon(Icons.stop),
            tooltip: 'Stop',
            onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaStop) : null,
          ),
          const SizedBox(height: 36),

          // Volume Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Master Volume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.volume_off),
                        tooltip: 'Mute / Unmute',
                        onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaVolumeMute) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.volume_down),
                          label: const Text('Volume Down'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaVolumeDown, {'steps': 2}) : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.volume_up),
                          label: const Text('Volume Up'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: isConnected ? () => _sendMediaCommand(CommandTypes.mediaVolumeUp, {'steps': 2}) : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
