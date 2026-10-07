import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';

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
          const SnackBar(content: Text('Copied text to Windows PC clipboard!')),
        );
        _sendController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set PC clipboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Push to PC
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phone → Windows PC Clipboard',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sendController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter or paste text here to send to PC...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.paste),
                        label: const Text('Paste Phone Clipboard'),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          if (data?.text != null) {
                            _sendController.text = data!.text!;
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.send_to_mobile),
                        label: const Text('Push to PC'),
                        onPressed: isConnected ? _sendToPcClipboard : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Fetch from PC
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Windows PC → Phone Clipboard',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: _isLoadingPcClipboard
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        onPressed: isConnected ? _fetchPcClipboard : null,
                      ),
                    ],
                  ),
                  const Divider(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _pcClipboardText.isEmpty ? '(PC clipboard text will appear here)' : _pcClipboardText,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _pcClipboardText.isEmpty ? Colors.grey : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_pcClipboardText.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy to Phone'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _pcClipboardText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to phone clipboard!')),
                          );
                        },
                      ),
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
