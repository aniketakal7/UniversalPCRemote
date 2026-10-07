import 'package:flutter/material.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';

class SystemScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const SystemScreen({super.key, required this.stateManager});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  Map<String, dynamic>? _systemInfo;
  bool _isLoadingInfo = false;

  @override
  void initState() {
    super.initState();
    if (widget.stateManager.isConnected) {
      _fetchSystemInfo();
    }
  }

  Future<void> _fetchSystemInfo() async {
    if (!widget.stateManager.isConnected) return;
    setState(() => _isLoadingInfo = true);

    try {
      final resp = await widget.stateManager.client.sendCommand(CommandTypes.systemGetInfo);
      if (resp.success && resp.data != null) {
        setState(() {
          _systemInfo = Map<String, dynamic>.from(resp.data as Map);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  Future<void> _sendLock() async {
    try {
      await widget.stateManager.client.sendCommand(CommandTypes.systemLock);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workstation locked successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lock failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendSleep() async {
    try {
      await widget.stateManager.client.sendCommand(CommandTypes.systemSleep);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sleep command sent to PC.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sleep failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmAndExecute({
    required String title,
    required String message,
    required String commandType,
    required Color actionColor,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: actionColor),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: actionColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.stateManager.client.sendCommand(commandType, {'confirm': true});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title scheduled successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title error: $e'), backgroundColor: Colors.red),
          );
        }
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
          // System Info Card
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
                        'PC Status & Hardware',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: _isLoadingInfo
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh),
                        onPressed: isConnected ? _fetchSystemInfo : null,
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_systemInfo != null) ...[
                    _buildInfoRow('Computer Name', _systemInfo!['pcName']?.toString() ?? 'N/A'),
                    _buildInfoRow('Operating System', _systemInfo!['osVersion']?.toString() ?? 'N/A'),
                    _buildInfoRow('Uptime', _systemInfo!['uptime']?.toString() ?? 'N/A'),
                    if (_systemInfo!['batteryPercent'] != null)
                      _buildInfoRow(
                        'Battery',
                        '${_systemInfo!['batteryPercent']}% ${_systemInfo!['isCharging'] == true ? "(Charging)" : ""}',
                      ),
                  ] else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Tap refresh to load real PC status.', style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Safe Actions
          Text('Workstation Control', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock Workstation'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: isConnected ? _sendLock : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.bedtime_outlined),
                  label: const Text('Sleep PC'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: isConnected ? _sendSleep : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dangerous Power Actions (With Confirmation)
          Text('Power Controls (Confirmation Required)', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red.shade700)),
          const SizedBox(height: 8),
          Card(
            color: Colors.red.shade50.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.restart_alt, color: Colors.orange),
                    title: const Text('Restart Computer', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Reboots the remote PC safely'),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                      onPressed: isConnected
                          ? () => _confirmAndExecute(
                                title: 'Restart PC',
                                message: 'Are you sure you want to restart your Windows PC? Any unsaved work will be closed.',
                                commandType: CommandTypes.systemRestart,
                                actionColor: Colors.orange,
                              )
                          : null,
                      child: const Text('Restart'),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.power_settings_new, color: Colors.red),
                    title: const Text('Shut Down Computer', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Powers off the remote PC'),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: isConnected
                          ? () => _confirmAndExecute(
                                title: 'Shutdown PC',
                                message: 'Are you sure you want to shut down your Windows PC? The connection will terminate.',
                                commandType: CommandTypes.systemShutdown,
                                actionColor: Colors.red,
                              )
                          : null,
                      child: const Text('Shut Down'),
                    ),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Abort / Cancel Scheduled Shutdown'),
                      onPressed: isConnected
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await widget.stateManager.client.sendCommand(CommandTypes.systemCancelShutdown);
                              if (mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Cancelled any pending shutdown.')),
                                );
                              }
                            }
                          : null,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
