import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';

class RemotesScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const RemotesScreen({super.key, required this.stateManager});

  @override
  State<RemotesScreen> createState() => _RemotesScreenState();
}

class _RemotesScreenState extends State<RemotesScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _remotes = [];
  List<dynamic> _macros = [];
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.stateManager.isConnected) {
      _loadRemotesAndMacros();
    }
  }

  Future<void> _loadRemotesAndMacros() async {
    if (!widget.stateManager.isConnected) return;
    setState(() => _isLoading = true);

    try {
      final remotesResp = await widget.stateManager.client.sendCommand(CommandTypes.remoteList);
      final macrosResp = await widget.stateManager.client.sendCommand(CommandTypes.macroList);

      if (mounted) {
        setState(() {
          _remotes = remotesResp.data as List? ?? [];
          _macros = macrosResp.data as List? ?? [];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeRemoteAction(String remoteId, String actionId) async {
    if (!widget.stateManager.isConnected) return;
    HapticFeedback.lightImpact();

    try {
      await widget.stateManager.client.sendCommand(
        CommandTypes.remoteExecute,
        {'remoteId': remoteId, 'actionId': actionId},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), duration: const Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _executeMacro(String macroId) async {
    if (!widget.stateManager.isConnected) return;
    HapticFeedback.mediumImpact();

    try {
      await widget.stateManager.client.sendCommand(
        CommandTypes.macroExecute,
        {'macroId': macroId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Macro executed successfully.'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Macro failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  IconData _resolveIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'play_arrow': return Icons.play_arrow;
      case 'skip_next': return Icons.skip_next;
      case 'skip_previous': return Icons.skip_previous;
      case 'fullscreen': return Icons.fullscreen;
      case 'subtitles': return Icons.subtitles;
      case 'volume_up': return Icons.volume_up;
      case 'volume_down': return Icons.volume_down;
      case 'volume_off': return Icons.volume_off;
      case 'arrow_back': return Icons.arrow_back;
      case 'arrow_forward': return Icons.arrow_forward;
      case 'add': return Icons.add;
      case 'close': return Icons.close;
      case 'refresh': return Icons.refresh;
      case 'replay_5': return Icons.replay_5;
      case 'forward_5': return Icons.forward_5;
      case 'slideshow': return Icons.slideshow;
      case 'navigate_before': return Icons.navigate_before;
      case 'navigate_next': return Icons.navigate_next;
      case 'dark_mode': return Icons.dark_mode;
      case 'light_mode': return Icons.light_mode;
      case 'stop': return Icons.stop;
      default: return Icons.touch_app;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.apps), text: 'App Remotes'),
            Tab(icon: Icon(Icons.bolt), text: 'Safe Macros'),
          ],
        ),
        if (_isLoading) const LinearProgressIndicator(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Remotes Tab
              _remotes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.extension_off_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No remotes loaded.'),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: isConnected ? _loadRemotesAndMacros : null,
                            child: const Text('Load Remotes'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _remotes.length,
                      itemBuilder: (ctx, idx) {
                        final remote = _remotes[idx] as Map<String, dynamic>;
                        final remoteId = remote['id'] as String;
                        final name = remote['name'] as String;
                        final desc = remote['description'] as String? ?? '';
                        final buttons = (remote['buttons'] as List?) ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                if (desc.isNotEmpty)
                                  Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                                const SizedBox(height: 12),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 1.8,
                                  ),
                                  itemCount: buttons.length,
                                  itemBuilder: (bCtx, bIdx) {
                                    final btn = buttons[bIdx] as Map<String, dynamic>;
                                    final label = btn['label'] as String;
                                    final iconStr = btn['icon'] as String? ?? '';
                                    final actionId = btn['actionId'] as String;

                                    return FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: isConnected ? () => _executeRemoteAction(remoteId, actionId) : null,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(_resolveIcon(iconStr), size: 16),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              label,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

              // Macros Tab
              _macros.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flash_off, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No macros available.'),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: isConnected ? _loadRemotesAndMacros : null,
                            child: const Text('Refresh Macros'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _macros.length,
                      itemBuilder: (ctx, idx) {
                        final m = _macros[idx] as Map<String, dynamic>;
                        final macroId = m['id'] as String;
                        final name = m['name'] as String;
                        final desc = m['description'] as String? ?? '';
                        final steps = (m['steps'] as List?)?.length ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.bolt)),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$desc • $steps automated step(s)'),
                            trailing: FilledButton.tonal(
                              onPressed: isConnected ? () => _executeMacro(macroId) : null,
                              child: const Text('RUN'),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
