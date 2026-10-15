import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../discovery/udp_discovery.dart';
import '../../state/connection_state.dart';
import '../../widgets/glass_card.dart';

class DiscoveryScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const DiscoveryScreen({super.key, required this.stateManager});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _manualIpController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    widget.stateManager.addListener(_onStateChanged);
    widget.stateManager.startDiscovery();
  }

  @override
  void dispose() {
    widget.stateManager.removeListener(_onStateChanged);
    _radarController.dispose();
    _manualIpController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
      if (widget.stateManager.status == AppConnectionStatus.pairingRequired &&
          !widget.stateManager.isPairingDialogShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              widget.stateManager.status == AppConnectionStatus.pairingRequired &&
              !widget.stateManager.isPairingDialogShowing) {
            _showPairingDialog();
          }
        });
      }
    }
  }

  void _showPairingDialog() {
    if (widget.stateManager.isPairingDialogShowing || !mounted) return;
    widget.stateManager.isPairingDialogShowing = true;
    _pinController.clear();
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCardElevated : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: AppTheme.accentAmber, size: 28),
              SizedBox(width: 10),
              Text('Pairing Security PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Enter the 6-digit PIN shown on your PC screen:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  filled: true,
                  fillColor: isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
                ),
                onSubmitted: (val) async {
                  if (val.trim().length == 6) {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    final ok = await widget.stateManager.submitPairingPin(val.trim());
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(widget.stateManager.errorMessage ?? 'Pairing failed. Incorrect PIN.'),
                          backgroundColor: AppTheme.accentRose,
                          action: SnackBarAction(
                            label: 'Retry',
                            textColor: Colors.white,
                            onPressed: () => _showPairingDialog(),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx, rootNavigator: true).pop();
                widget.stateManager.disconnect();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () async {
                final pin = _pinController.text.trim();
                if (pin.length == 6) {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  final ok = await widget.stateManager.submitPairingPin(pin);
                  if (!ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.stateManager.errorMessage ?? 'Pairing failed. Incorrect PIN.'),
                        backgroundColor: AppTheme.accentRose,
                        action: SnackBarAction(
                          label: 'Retry',
                          textColor: Colors.white,
                          onPressed: () => _showPairingDialog(),
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirm PIN'),
            ),
          ],
        );
      },
    ).then((_) {
      widget.stateManager.isPairingDialogShowing = false;
    });
  }

  void _showHotspotHelp(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.wifi_tethering_rounded, color: AppTheme.secondary, size: 24),
            SizedBox(width: 10),
            Text('Phone Hotspot Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No Wi-Fi router needed! You can control your PC directly using your phone\'s hotspot:',
              style: TextStyle(fontSize: 13, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
            ),
            const SizedBox(height: 16),
            _buildHelpStep('1', 'Turn ON Mobile Hotspot on this phone.'),
            const SizedBox(height: 12),
            _buildHelpStep('2', 'Connect your Windows PC to this phone\'s hotspot Wi-Fi network.'),
            const SizedBox(height: 12),
            _buildHelpStep('3', 'Open Universal PC Remote Companion on PC. It will automatically detect the hotspot and link with low latency!'),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppTheme.secondary,
            shape: BoxShape.circle,
          ),
          child: Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.stateManager.status;
    final isConnected = widget.stateManager.isConnected;
    final isPairingRequired = status == AppConnectionStatus.pairingRequired;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isPairingRequired && !widget.stateManager.isPairingDialogShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!widget.stateManager.isPairingDialogShowing && mounted && widget.stateManager.status == AppConnectionStatus.pairingRequired) {
          _showPairingDialog();
        }
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active Connection Status Hero Card
          GlassCard(
            customBorderColor: isConnected
                ? AppTheme.accentGreen.withOpacity(0.4)
                : (isPairingRequired ? AppTheme.accentAmber.withOpacity(0.5) : null),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isConnected
                        ? AppTheme.greenGradient
                        : (isPairingRequired
                            ? const LinearGradient(colors: [AppTheme.accentAmber, Colors.deepOrangeAccent])
                            : AppTheme.primaryGradient),
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected
                                ? AppTheme.accentGreen
                                : (isPairingRequired ? AppTheme.accentAmber : AppTheme.primary))
                            .withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.check_circle_rounded
                        : (isPairingRequired ? Icons.shield_rounded : Icons.wifi_tethering_rounded),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected
                            ? widget.stateManager.displayName
                            : (isPairingRequired
                                ? 'Pairing PIN Required'
                                : (widget.stateManager.isConnecting ? 'Connecting...' : 'Searching for PC...')),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isConnected
                            ? 'IP: ${widget.stateManager.activeIp}:51234'
                            : (isPairingRequired
                                ? 'PIN code shown on ${widget.stateManager.displayName}'
                                : (widget.stateManager.errorMessage ?? 'Listening on Wi-Fi broadcast...')),
                        style: TextStyle(
                          fontSize: 12,
                          color: isPairingRequired
                              ? AppTheme.accentAmber
                              : (widget.stateManager.errorMessage != null
                                  ? AppTheme.accentRose
                                  : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  TactileButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    borderRadius: 12,
                    backgroundColor: AppTheme.accentRose.withOpacity(0.15),
                    borderColor: AppTheme.accentRose,
                    onPressed: () => widget.stateManager.disconnect(),
                    child: const Text('Disconnect', style: TextStyle(color: AppTheme.accentRose, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                else if (isPairingRequired)
                  TactileButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    borderRadius: 12,
                    gradient: const LinearGradient(colors: [AppTheme.accentAmber, Colors.deepOrangeAccent]),
                    onPressed: _showPairingDialog,
                    child: const Text('ENTER PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Mobile Hotspot Active Banner
          if (widget.stateManager.isHotspotActive) ...[
            GlassCard(
              customBorderColor: AppTheme.secondary.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_tethering_rounded, color: AppTheme.secondary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Hotspot Mode Active',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Phone Gateway: ${widget.stateManager.hotspotGatewayIp ?? "192.168.43.1"} • PC on Hotspot will auto-link',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TactileButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    borderRadius: 12,
                    gradient: AppTheme.primaryGradient,
                    onPressed: widget.stateManager.isHotspotScanning ? null : () => widget.stateManager.scanHotspot(),
                    child: widget.stateManager.isHotspotScanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.radar_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            const SizedBox(height: 10),
          ],

          // Discovered PCs Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Discovered Windows PCs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _radarController,
                    builder: (context, _) {
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withOpacity(0.3 + _radarController.value * 0.7),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 20),
                    tooltip: 'Hotspot Guide',
                    onPressed: () => _showHotspotHelp(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Scan Now',
                    onPressed: () => widget.stateManager.discovery.sendQuery(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Discovered PCs List
          StreamBuilder<List<DiscoveredPC>>(
            stream: widget.stateManager.discovery.discoveredPCsStream,
            initialData: widget.stateManager.discovery.currentPCs,
            builder: (context, snapshot) {
              final pcs = snapshot.data ?? [];
              if (pcs.isEmpty) {
                return GlassCard(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _radarController,
                          builder: (context, child) {
                            return Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primary.withOpacity(0.1 + _radarController.value * 0.15),
                                border: Border.all(
                                  color: AppTheme.primaryLight.withOpacity(1.0 - _radarController.value),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(Icons.radar_rounded, color: AppTheme.primaryLight, size: 28),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.stateManager.isHotspotActive
                              ? 'Scanning Hotspot Clients...'
                              : 'Scanning Local Wi-Fi Network...',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.stateManager.isHotspotActive
                              ? 'PC connected to this phone\'s hotspot? Tap below to scan directly:'
                              : 'Make sure Universal PC Remote Companion is running on your PC',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TactileButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          borderRadius: 14,
                          gradient: AppTheme.primaryGradient,
                          onPressed: widget.stateManager.isHotspotScanning
                              ? null
                              : () => widget.stateManager.scanHotspot(),
                          child: widget.stateManager.isHotspotScanning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.wifi_tethering_rounded, size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('Scan Hotspot Clients', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: pcs.map((pc) {
                  final isCurrent = widget.stateManager.activeIp == pc.ipAddress && isConnected;
                  final isCurrentPairing = widget.stateManager.activeIp == pc.ipAddress && isPairingRequired;

                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCurrentPairing
                                ? AppTheme.accentAmber.withOpacity(0.15)
                                : AppTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isCurrentPairing ? Icons.shield_rounded : Icons.laptop_windows_rounded,
                            color: isCurrentPairing ? AppTheme.accentAmber : AppTheme.primaryLight,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      pc.pcName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (pc.isHotspot) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.secondary.withOpacity(0.5), width: 1),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.wifi_tethering_rounded, size: 10, color: AppTheme.secondary),
                                          SizedBox(width: 3),
                                          Text('HOTSPOT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCurrentPairing
                                    ? 'PIN displayed on PC • Tap ENTER PIN'
                                    : '${pc.ipAddress}:${pc.port} • ${pc.os}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCurrentPairing
                                      ? AppTheme.accentAmber
                                      : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TactileButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          borderRadius: 12,
                          gradient: isCurrent
                              ? null
                              : (isCurrentPairing
                                  ? const LinearGradient(colors: [AppTheme.accentAmber, Colors.deepOrangeAccent])
                                  : AppTheme.primaryGradient),
                          isToggled: isCurrent,
                          onPressed: isCurrent
                              ? null
                              : (isCurrentPairing
                                  ? _showPairingDialog
                                  : () => widget.stateManager.connectToPC(pc.ipAddress, pc.port, pc.pcName)),
                          child: Text(
                            isCurrent
                                ? 'LINKED'
                                : (isCurrentPairing ? 'ENTER PIN' : 'CONNECT'),
                            style: TextStyle(
                              color: isCurrent ? AppTheme.accentGreen : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // Manual IP Connection Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: AppTheme.secondary, size: 22),
                    SizedBox(width: 10),
                    Text('Direct IP Connection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the IP address shown on the Windows companion window if UDP broadcast is blocked by your router:',
                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualIpController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 192.168.1.100',
                          filled: true,
                          fillColor: isDark ? AppTheme.darkCardElevated : const Color(0xFFF1F5F9),
                        ),
                        keyboardType: TextInputType.datetime,
                      ),
                    ),
                    const SizedBox(width: 10),
                    TactileButton(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      borderRadius: 16,
                      gradient: isPairingRequired
                          ? const LinearGradient(colors: [AppTheme.accentAmber, Colors.deepOrangeAccent])
                          : AppTheme.primaryGradient,
                      onPressed: () {
                        if (isPairingRequired) {
                          _showPairingDialog();
                          return;
                        }
                        final raw = _manualIpController.text.trim();
                        if (raw.isNotEmpty) {
                          String host = raw;
                          int port = 51234;

                          if (host.startsWith('ws://')) {
                            host = host.substring(5);
                          } else if (host.startsWith('wss://')) {
                            host = host.substring(6);
                          } else if (host.startsWith('http://')) {
                            host = host.substring(7);
                          } else if (host.startsWith('https://')) {
                            host = host.substring(8);
                          }

                          if (host.contains('/')) host = host.split('/').first;

                          if (host.contains(':') && !host.contains(']')) {
                            final parts = host.split(':');
                            if (parts.length == 2 && int.tryParse(parts[1]) != null) {
                              host = parts[0];
                              port = int.parse(parts[1]);
                            }
                          }

                          widget.stateManager.connectToPC(host, port);
                        }
                      },
                      child: Text(
                        isPairingRequired ? 'ENTER PIN' : 'Connect',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Saved Paired Computers Section
          Text(
            'Saved Paired Computers',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
          ),
          const SizedBox(height: 10),

          widget.stateManager.pairing.pairedPcs.isEmpty
              ? GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No saved computers paired yet. Connect above to pair automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                    ),
                  ),
                )
              : Column(
                  children: widget.stateManager.pairing.pairedPcs.map((p) {
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: AppTheme.accentGreen, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.pcName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('IP: ${p.ip} • Paired: ${p.pairedAt.toString().substring(0, 10)}',
                                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentRose, size: 20),
                            tooltip: 'Forget Device',
                            onPressed: () async {
                              await widget.stateManager.pairing.forgetDevice(p.ip);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}
