import 'package:flutter/material.dart';
import '../../core/app_haptics.dart';
import '../../core/app_theme.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';
import '../../widgets/glass_card.dart';

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
  String _selectedCategory = 'All';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    widget.stateManager.addListener(_onStateChanged);
    if (widget.stateManager.isConnected) {
      _loadRemotesAndMacros();
    }
  }

  void _onStateChanged() {
    if (widget.stateManager.isConnected && _remotes.isEmpty && !_isLoading) {
      _loadRemotesAndMacros();
    }
  }

  @override
  void dispose() {
    widget.stateManager.removeListener(_onStateChanged);
    _tabController.dispose();
    super.dispose();
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
    AppHaptics.click();

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
    AppHaptics.action();

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
          SnackBar(content: Text('Macro failed: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    }
  }

  void _sendKey(String key) {
    if (!widget.stateManager.isConnected) return;
    AppHaptics.click();
    widget.stateManager.client.sendFastCommand(CommandTypes.keyboardKey, {'key': key});
  }

  IconData _resolveIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'play_arrow': return Icons.play_arrow_rounded;
      case 'skip_next': return Icons.skip_next_rounded;
      case 'skip_previous': return Icons.skip_previous_rounded;
      case 'fullscreen': return Icons.fullscreen_rounded;
      case 'subtitles': return Icons.subtitles_rounded;
      case 'volume_up': return Icons.volume_up_rounded;
      case 'volume_down': return Icons.volume_down_rounded;
      case 'volume_off': return Icons.volume_off_rounded;
      case 'arrow_back': return Icons.arrow_back_rounded;
      case 'arrow_forward': return Icons.arrow_forward_rounded;
      case 'arrow_downward': return Icons.arrow_downward_rounded;
      case 'add': return Icons.add_rounded;
      case 'close': return Icons.close_rounded;
      case 'refresh': return Icons.refresh_rounded;
      case 'replay_5': return Icons.replay_5_rounded;
      case 'forward_5': return Icons.forward_5_rounded;
      case 'replay_10': return Icons.replay_10_rounded;
      case 'forward_10': return Icons.forward_10_rounded;
      case 'slideshow': return Icons.slideshow_rounded;
      case 'navigate_before': return Icons.navigate_before_rounded;
      case 'navigate_next': return Icons.navigate_next_rounded;
      case 'dark_mode': return Icons.dark_mode_rounded;
      case 'light_mode': return Icons.light_mode_rounded;
      case 'stop': return Icons.stop_rounded;
      case 'shuffle': return Icons.shuffle_rounded;
      case 'repeat': return Icons.repeat_rounded;
      case 'favorite': return Icons.favorite_rounded;
      case 'tv': return Icons.tv_rounded;
      case 'branding_watermark': return Icons.branding_watermark_rounded;
      case 'closed_caption': return Icons.closed_caption_rounded;
      case 'speed': return Icons.speed_rounded;
      case 'fast_forward': return Icons.fast_forward_rounded;
      case 'mic': return Icons.mic_rounded;
      case 'mic_off': return Icons.mic_off_rounded;
      case 'headset_off': return Icons.headset_off_rounded;
      case 'videocam': return Icons.videocam_rounded;
      case 'call': return Icons.call_rounded;
      case 'call_end': return Icons.call_end_rounded;
      case 'search': return Icons.search_rounded;
      case 'keyboard_arrow_up': return Icons.keyboard_arrow_up_rounded;
      case 'keyboard_arrow_down': return Icons.keyboard_arrow_down_rounded;
      case 'done_all': return Icons.done_all_rounded;
      case 'push_pin': return Icons.push_pin_rounded;
      case 'terminal': return Icons.terminal_rounded;
      case 'folder': return Icons.folder_rounded;
      case 'code': return Icons.code_rounded;
      case 'vertical_split': return Icons.vertical_split_rounded;
      case 'save': return Icons.save_rounded;
      case 'dashboard': return Icons.dashboard_rounded;
      case 'podcasts': return Icons.podcasts_rounded;
      case 'fiber_manual_record': return Icons.fiber_manual_record_rounded;
      case 'pause': return Icons.pause_rounded;
      case 'replay': return Icons.replay_rounded;
      case 'camera_alt': return Icons.camera_alt_rounded;
      case 'desktop_windows': return Icons.desktop_windows_rounded;
      case 'settings': return Icons.settings_rounded;
      case 'lock': return Icons.lock_rounded;
      case 'crop_square': return Icons.crop_square_rounded;
      case 'remove': return Icons.remove_rounded;
      case 'notifications': return Icons.notifications_rounded;
      case 'screen_share': return Icons.screen_share_rounded;
      case 'pan_tool': return Icons.pan_tool_rounded;
      case 'chat': return Icons.chat_rounded;
      case 'people': return Icons.people_rounded;
      default: return Icons.touch_app_rounded;
    }
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  IconData _resolveRemoteHeaderIcon(String remoteId, String category) {
    switch (remoteId.toLowerCase()) {
      case 'spotify': return Icons.music_note_rounded;
      case 'youtube': return Icons.play_circle_fill_rounded;
      case 'netflix': return Icons.movie_filter_rounded;
      case 'vlc': return Icons.video_library_rounded;
      case 'browser': return Icons.language_rounded;
      case 'discord': return Icons.forum_rounded;
      case 'vscode': return Icons.code_rounded;
      case 'obs': return Icons.podcasts_rounded;
      case 'windows': return Icons.desktop_windows_rounded;
      case 'meetings': return Icons.video_call_rounded;
      case 'presentation': return Icons.co_present_rounded;
      default:
        switch (category.toLowerCase()) {
          case 'media': return Icons.play_circle_outline_rounded;
          case 'web': return Icons.public_rounded;
          case 'social': return Icons.chat_rounded;
          case 'developer': return Icons.terminal_rounded;
          case 'streaming': return Icons.live_tv_rounded;
          case 'system': return Icons.desktop_windows_rounded;
          default: return Icons.apps_rounded;
        }
    }
  }

  Color _resolveRemoteHeaderColor(String remoteId) {
    switch (remoteId.toLowerCase()) {
      case 'spotify': return const Color(0xFF1DB954);
      case 'youtube': return const Color(0xFFFF0000);
      case 'netflix': return const Color(0xFFE50914);
      case 'vlc': return const Color(0xFFFF8800);
      case 'browser': return const Color(0xFF00B0FF);
      case 'discord': return const Color(0xFF5865F2);
      case 'vscode': return const Color(0xFF007ACC);
      case 'obs': return const Color(0xFF9B59B6);
      case 'windows': return const Color(0xFF0078D7);
      case 'meetings': return const Color(0xFF2D8CFF);
      case 'presentation': return const Color(0xFFE67E22);
      default: return AppTheme.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Premium Tab Bar Header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'App Remotes'),
              Tab(text: 'Slides Deck'),
              Tab(text: 'Safe Macros'),
            ],
          ),
        ),

        if (_isLoading) const LinearProgressIndicator(minHeight: 2),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. App Remotes Tab
              _remotes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.extension_off_rounded, size: 52, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 14),
                          const Text('No app remotes loaded yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('Connect to PC and load remote profiles', style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                          const SizedBox(height: 16),
                          TactileButton(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            borderRadius: 14,
                            gradient: AppTheme.primaryGradient,
                            onPressed: isConnected ? _loadRemotesAndMacros : null,
                            child: const Text('Load Profiles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final rawCategories = _remotes
                            .map((r) => (r as Map<String, dynamic>)['category'] as String? ?? 'General')
                            .toSet()
                            .toList();
                        rawCategories.sort();
                        final categories = ['All', ...rawCategories];

                        final filteredRemotes = _selectedCategory == 'All'
                            ? _remotes
                            : _remotes.where((r) => ((r as Map<String, dynamic>)['category'] as String? ?? 'General') == _selectedCategory).toList();

                        return Column(
                          children: [
                            // Horizontal Category Filter Pills
                            if (categories.length > 2)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: Row(
                                  children: categories.map((cat) {
                                    final isSelected = _selectedCategory == cat;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: FilterChip(
                                        label: Text(cat),
                                        selected: isSelected,
                                        onSelected: (_) => setState(() => _selectedCategory = cat),
                                        selectedColor: AppTheme.primary.withOpacity(0.25),
                                        checkmarkColor: AppTheme.primaryLight,
                                        labelStyle: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? AppTheme.primaryLight : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                        ),
                                        backgroundColor: isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        side: BorderSide(
                                          color: isSelected ? AppTheme.primaryLight : (isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                            // Remotes List
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _loadRemotesAndMacros,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  itemCount: filteredRemotes.length,
                                  itemBuilder: (ctx, idx) {
                                    final remote = filteredRemotes[idx] as Map<String, dynamic>;
                                    final remoteId = remote['id'] as String;
                                    final name = remote['name'] as String;
                                    final category = remote['category'] as String? ?? '';
                                    final desc = remote['description'] as String? ?? '';
                                    final buttons = (remote['buttons'] as List?) ?? [];
                                    final headerColor = _resolveRemoteHeaderColor(remoteId);
                                    final headerIcon = _resolveRemoteHeaderIcon(remoteId, category);

                                    return GlassCard(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: headerColor.withOpacity(0.16),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(headerIcon, color: headerColor, size: 22),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            name,
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                          ),
                                                        ),
                                                        if (category.isNotEmpty) ...[
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: headerColor.withOpacity(0.12),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              category.toUpperCase(),
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                                color: headerColor,
                                                                letterSpacing: 0.5,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    if (desc.isNotEmpty)
                                                      Text(
                                                        desc,
                                                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          GridView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              mainAxisSpacing: 10,
                                              crossAxisSpacing: 10,
                                              childAspectRatio: 1.8,
                                            ),
                                            itemCount: buttons.length,
                                            itemBuilder: (bCtx, bIdx) {
                                              final btn = buttons[bIdx] as Map<String, dynamic>;
                                              final label = btn['label'] as String;
                                              final iconStr = btn['icon'] as String? ?? '';
                                              final actionId = btn['actionId'] as String;
                                              final colorHex = btn['colorHex'] as String?;
                                              final customColor = _parseHexColor(colorHex);

                                              return TactileButton(
                                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                                borderRadius: 12,
                                                onPressed: isConnected ? () => _executeRemoteAction(remoteId, actionId) : null,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      _resolveIcon(iconStr),
                                                      size: 16,
                                                      color: customColor ?? AppTheme.primaryLight,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        label,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

              // 2. Dedicated Presentation Deck (PowerPoint / Google Slides / Keynote)
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.co_present_rounded, size: 48, color: AppTheme.secondary),
                          const SizedBox(height: 10),
                          const Text('Presentation Controller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text('Optimized for PowerPoint, Google Slides & Keynote', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                          const SizedBox(height: 24),

                          // Giant Next / Previous Buttons
                          Row(
                            children: [
                              Expanded(
                                child: TactileButton(
                                  padding: const EdgeInsets.symmetric(vertical: 28),
                                  borderRadius: 20,
                                  onPressed: isConnected ? () => _sendKey('LEFT') : null,
                                  child: const Column(
                                    children: [
                                      Icon(Icons.arrow_back_rounded, size: 36),
                                      SizedBox(height: 8),
                                      Text('PREVIOUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 2,
                                child: TactileButton(
                                  padding: const EdgeInsets.symmetric(vertical: 28),
                                  borderRadius: 20,
                                  gradient: AppTheme.primaryGradient,
                                  onPressed: isConnected ? () => _sendKey('RIGHT') : null,
                                  child: const Column(
                                    children: [
                                      Icon(Icons.arrow_forward_rounded, size: 42, color: Colors.white),
                                      SizedBox(height: 8),
                                      Text('NEXT SLIDE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Secondary Presentation Tools
                          Row(
                            children: [
                              Expanded(
                                child: TactileButton(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  borderRadius: 14,
                                  onPressed: isConnected ? () => _sendKey('F5') : null,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.play_circle_outline_rounded, size: 18),
                                      SizedBox(width: 6),
                                      Text('Start (F5)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TactileButton(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  borderRadius: 14,
                                  onPressed: isConnected ? () => _sendKey('B') : null,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.pause_presentation_rounded, size: 18),
                                      SizedBox(width: 6),
                                      Text('Blank (B)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TactileButton(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  borderRadius: 14,
                                  onPressed: isConnected ? () => _sendKey('ESCAPE') : null,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.stop_circle_outlined, size: 18),
                                      SizedBox(width: 6),
                                      Text('Exit (Esc)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Safe Macros Tab
              _macros.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_outlined, size: 52, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 14),
                          const Text('No macros available', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('Macros automate multiple keystrokes or tasks', style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                          const SizedBox(height: 16),
                          TactileButton(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            borderRadius: 14,
                            gradient: AppTheme.primaryGradient,
                            onPressed: isConnected ? _loadRemotesAndMacros : null,
                            child: const Text('Refresh Macros', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _macros.length,
                      itemBuilder: (ctx, idx) {
                        final m = _macros[idx] as Map<String, dynamic>;
                        final macroId = m['id'] as String;
                        final name = m['name'] as String;
                        final desc = m['description'] as String? ?? '';
                        final steps = (m['steps'] as List?)?.length ?? 0;

                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPurple.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.bolt_rounded, color: AppTheme.accentPurple, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Text('$desc • $steps step(s)', style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                                  ],
                                ),
                              ),
                              TactileButton(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                borderRadius: 12,
                                gradient: AppTheme.purpleGradient,
                                onPressed: isConnected ? () => _executeMacro(macroId) : null,
                                child: const Text('RUN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
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
