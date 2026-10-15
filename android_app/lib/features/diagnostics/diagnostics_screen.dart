import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';
import '../../widgets/glass_card.dart';

class DiagnosticsScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const DiagnosticsScreen({super.key, required this.stateManager});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _isRunning = false;
  int? _pingLatencyMs;
  List<dynamic> _companionItems = [];
  String? _lastError;

  Future<void> _runFullDiagnostics() async {
    setState(() {
      _isRunning = true;
      _lastError = null;
      _companionItems.clear();
      _pingLatencyMs = null;
    });

    try {
      // 1. Measure ping latency
      final stopwatch = Stopwatch()..start();
      final pingResp = await widget.stateManager.client.sendCommand(CommandTypes.sessionPing);
      stopwatch.stop();

      if (pingResp.success) {
        _pingLatencyMs = stopwatch.elapsedMilliseconds;
      }

      // 2. Fetch Companion Subsystem Diagnostics Report
      final diagResp = await widget.stateManager.client.sendCommand(CommandTypes.diagnosticsStatus);
      if (diagResp.success && diagResp.data != null) {
        final data = diagResp.data as Map<String, dynamic>;
        _companionItems = (data['items'] as List?) ?? [];
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      if (mounted) setState(() => _isRunning = false);
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
          // Diagnostics Header Hero
          GlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.speed_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 16),
                const Text(
                  'End-to-End Latency & Subsystems',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 6),
                Text(
                  'Measures WebSocket ping roundtrip, thread responsiveness, and Windows companion drivers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                ),
                const SizedBox(height: 20),
                TactileButton(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  borderRadius: 16,
                  gradient: AppTheme.primaryGradient,
                  onPressed: isConnected && !_isRunning ? _runFullDiagnostics : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isRunning) ...[
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 10),
                      ] else ...[
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _isRunning ? 'Testing Subsystems...' : 'Run Diagnostics Benchmark',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_lastError != null)
            GlassCard(
              customBorderColor: AppTheme.accentRose,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.accentRose),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Error: $_lastError', style: const TextStyle(color: AppTheme.accentRose, fontSize: 13)),
                  ),
                ],
              ),
            ),

          // Latency Gauge Card
          if (_pingLatencyMs != null) ...[
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.network_check_rounded, color: AppTheme.accentGreen, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('WebSocket Roundtrip Ping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(
                          'Local Wi-Fi Network Latency',
                          style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_pingLatencyMs ms',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppTheme.accentGreen),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _pingLatencyMs! < 20 ? 'ULTRA FAST' : (_pingLatencyMs! < 60 ? 'OPTIMAL' : 'ACCEPTABLE'),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Subsystem Health Checklist
          if (_companionItems.isNotEmpty) ...[
            Text(
              'Windows Subsystem Verification',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            ..._companionItems.map((item) {
              final sub = item['subsystem'] as String;
              final status = item['status'] as String;
              final msg = item['message'] as String;
              final details = item['details'] as String? ?? '';
              final isPass = status == 'PASS';

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isPass ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isPass ? AppTheme.accentGreen : AppTheme.accentRose,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sub, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(msg, style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(details, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isPass ? AppTheme.accentGreen : AppTheme.accentRose).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPass ? AppTheme.accentGreen : AppTheme.accentRose,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
