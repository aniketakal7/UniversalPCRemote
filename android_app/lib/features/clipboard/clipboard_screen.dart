import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_haptics.dart';
import '../../core/app_theme.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';
import '../../widgets/glass_card.dart';

class ClipboardScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const ClipboardScreen({super.key, required this.stateManager});

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen> {
  final TextEditingController _sendController = TextEditingController();
  String _pcClipboardText = '';
  bool _isLoadingPcClipboard = false;

  Future<void> _fetchPcClipboard() async {
    if (!widget.stateManager.isConnected) return;
    setState(() => _isLoadingPcClipboard = true);

    try {
      final resp = await widget.stateManager.client.sendCommand(CommandTypes.clipboardGet);
      if (resp.success && resp.data != null) {
        setState(() {
          _pcClipboardText = resp.data['text']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read PC clipboard: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPcClipboard = false);
    }
  }

  Future<void> _sendToPcClipboard() async {
    if (!widget.stateManager.isConnected || _sendController.text.isEmpty) return;

    try {
      final resp = await widget.stateManager.client.sendCommand(
        CommandTypes.clipboardSet,
        {'text': _sendController.text},
      );
      if (resp.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transferred text to Windows PC clipboard!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        _sendController.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set PC clipboard: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Push to PC Section
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Phone → PC Clipboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Send text directly into Windows clipboard', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _sendController,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Type or paste text to send to your PC...',
                    filled: true,
                    fillColor: isDark ? AppTheme.darkCardElevated : const Color(0xFFF1F5F9),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_sendController.text.length} chars',
                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                    ),
                    Row(
                      children: [
                        TactileButton(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          borderRadius: 12,
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null) {
                              _sendController.text = data!.text!;
                              setState(() {});
                            }
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.content_paste_rounded, size: 16),
                              SizedBox(width: 6),
                              Text('Paste', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        TactileButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          borderRadius: 12,
                          gradient: AppTheme.primaryGradient,
                          onPressed: isConnected && _sendController.text.isNotEmpty ? _sendToPcClipboard : null,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send_rounded, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Push to PC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pull from PC Section
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_downward_rounded, color: AppTheme.secondary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PC → Phone Clipboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Fetch current text on Windows PC', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: _isLoadingPcClipboard
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded),
                      tooltip: 'Fetch PC Clipboard',
                      onPressed: isConnected ? _fetchPcClipboard : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  constraints: const Duration(milliseconds: 100) == const Duration(milliseconds: 100)
                      ? const BoxConstraints(minHeight: 80, maxHeight: 180)
                      : null,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardElevated : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _pcClipboardText.isEmpty
                          ? (isConnected
                              ? 'Tap the refresh button above to read PC clipboard...'
                              : 'Connect to PC to read clipboard contents')
                          : _pcClipboardText,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: _pcClipboardText.isEmpty
                            ? (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)
                            : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                      ),
                    ),
                  ),
                ),
                if (_pcClipboardText.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_pcClipboardText.length} characters',
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                      ),
                      TactileButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        borderRadius: 12,
                        gradient: AppTheme.greenGradient,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _pcClipboardText));
                          AppHaptics.tick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied PC text to phone clipboard!'),
                              backgroundColor: AppTheme.accentGreen,
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Copy to Phone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
