import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../state/connection_state.dart';

class StatusPill extends StatefulWidget {
  final ConnectionStateManager stateManager;
  final VoidCallback? onTap;

  const StatusPill({super.key, required this.stateManager, this.onTap});

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;
    final isConnecting = widget.stateManager.isConnecting;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    final isPairing = widget.stateManager.status == AppConnectionStatus.pairingRequired;

    if (isConnected) {
      statusColor = AppTheme.accentGreen;
      statusText = widget.stateManager.displayName;
    } else if (isConnecting) {
      statusColor = AppTheme.accentAmber;
      statusText = 'Connecting...';
    } else if (isPairing) {
      statusColor = AppTheme.accentAmber;
      statusText = 'Pairing PIN Required';
    } else {
      statusColor = AppTheme.accentRose;
      statusText = 'Disconnected';
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (isConnected || isPairing)
              ? statusColor.withOpacity(0.12)
              : (isDark ? AppTheme.darkCardElevated : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (isConnected || isPairing) ? statusColor.withOpacity(0.35) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final opacity = isConnected
                    ? 0.5 + (_pulseController.value * 0.5)
                    : ((isConnecting || isPairing) ? 0.3 + (_pulseController.value * 0.7) : 1.0);
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(opacity),
                    boxShadow: (isConnected || isPairing)
                        ? [
                            BoxShadow(
                              color: statusColor.withOpacity(_pulseController.value * 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                statusText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (isConnected && widget.stateManager.activeIp != null) ...[
              const SizedBox(width: 5),
              Text(
                '• ${widget.stateManager.activeIp}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
