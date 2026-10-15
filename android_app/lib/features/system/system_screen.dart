import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';
import '../../widgets/glass_card.dart';

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
          SnackBar(content: Text('Lock failed: $e'), backgroundColor: AppTheme.accentRose),
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
          SnackBar(content: Text('Sleep failed: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    }
  }

  Future<void> _confirmAndExecute({
    required String title,
    required String message,
    required String commandType,
    required Color actionColor,
    required IconData icon,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark ? AppTheme.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: actionColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: actionColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Execute'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.stateManager.client.sendCommand(commandType, {'confirm': true});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title scheduled successfully.'),
              backgroundColor: actionColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title error: $e'), backgroundColor: AppTheme.accentRose),
          );
        }
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
          // Live PC Telemetry Card
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
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.computer_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PC Hardware & Status',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              isConnected ? 'Online & Linked' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                color: isConnected ? AppTheme.accentGreen : AppTheme.accentRose,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: _isLoadingInfo
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh Status',
                      onPressed: isConnected ? _fetchSystemInfo : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder),
                const SizedBox(height: 8),

                if (_systemInfo != null) ...[
                  _buildTelemetryRow(
                    Icons.laptop_windows_rounded,
                    'Computer Name',
                    _systemInfo!['pcName']?.toString() ?? 'N/A',
                  ),
                  _buildTelemetryRow(
                    Icons.window_rounded,
                    'Operating System',
                    _systemInfo!['osVersion']?.toString() ?? 'N/A',
                  ),
                  _buildTelemetryRow(
                    Icons.timer_outlined,
                    'System Uptime',
                    _systemInfo!['uptime']?.toString() ?? 'N/A',
                  ),
                  if (_systemInfo!['batteryPercent'] != null) ...[
                    const SizedBox(height: 8),
                    _buildBatteryTelemetry(
                      _systemInfo!['batteryPercent'] as num,
                      _systemInfo!['isCharging'] == true,
                    ),
                  ],
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(
                      child: Text(
                        isConnected
                            ? 'Tap the refresh button to query PC status'
                            : 'Connect to PC to view hardware telemetry',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Safe Workstation Quick Actions
          Text(
            'Workstation Quick Controls',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: GlassCard(
                  onTap: isConnected ? _sendLock : null,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryLight, size: 24),
                      ),
                      const SizedBox(height: 10),
                      const Text('Lock PC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Win + L', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  onTap: isConnected ? _sendSleep : null,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bedtime_rounded, color: AppTheme.secondary, size: 24),
                      ),
                      const SizedBox(height: 10),
                      const Text('Sleep PC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Low Power', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // High-Impact Power Controls
          Text(
            'Critical Power Controls',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentRose,
                ),
          ),
          const SizedBox(height: 10),

          GlassCard(
            customBorderColor: AppTheme.accentRose.withOpacity(0.35),
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restart_alt_rounded, color: AppTheme.accentAmber, size: 24),
                  ),
                  title: const Text('Restart Computer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Reboots the remote PC safely', style: TextStyle(fontSize: 12)),
                  trailing: TactileButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    borderRadius: 12,
                    backgroundColor: AppTheme.accentAmber.withOpacity(0.15),
                    borderColor: AppTheme.accentAmber,
                    onPressed: isConnected
                        ? () => _confirmAndExecute(
                              title: 'Restart PC',
                              message: 'Are you sure you want to restart your Windows PC? Any unsaved work will be closed.',
                              commandType: CommandTypes.systemRestart,
                              actionColor: AppTheme.accentAmber,
                              icon: Icons.restart_alt_rounded,
                            )
                        : null,
                    child: const Text('Restart', style: TextStyle(color: AppTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                Divider(color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.power_settings_new_rounded, color: AppTheme.accentRose, size: 24),
                  ),
                  title: const Text('Shut Down Computer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Powers off the remote machine', style: TextStyle(fontSize: 12)),
                  trailing: TactileButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    borderRadius: 12,
                    gradient: AppTheme.dangerGradient,
                    onPressed: isConnected
                        ? () => _confirmAndExecute(
                              title: 'Shutdown PC',
                              message: 'Are you sure you want to shut down your Windows PC? The connection will terminate.',
                              commandType: CommandTypes.systemShutdown,
                              actionColor: AppTheme.accentRose,
                              icon: Icons.power_settings_new_rounded,
                            )
                        : null,
                    child: const Text('Shut Down', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                Divider(color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.primaryLight),
                    label: const Text('Abort / Cancel Scheduled Shutdown', style: TextStyle(color: AppTheme.primaryLight, fontSize: 12)),
                    onPressed: isConnected
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await widget.stateManager.client.sendCommand(CommandTypes.systemCancelShutdown);
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Cancelled any pending shutdown countdown.')),
                              );
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBatteryTelemetry(num percent, bool isCharging) {
    final pClamped = percent.clamp(0, 100) / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isCharging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded,
                  size: 18,
                  color: isCharging ? AppTheme.accentGreen : AppTheme.primaryLight,
                ),
                const SizedBox(width: 8),
                Text('Battery Level', style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
              ],
            ),
            Text(
              '$percent% ${isCharging ? "(Charging)" : ""}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isCharging ? AppTheme.accentGreen : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pClamped,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(isCharging ? AppTheme.accentGreen : AppTheme.primary),
          ),
        ),
      ],
    );
  }
}
