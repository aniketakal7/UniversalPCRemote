import 'package:flutter/material.dart';
import '../../protocol/models.dart';
import '../../state/connection_state.dart';

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'End-to-End Diagnostics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tests network roundtrip latency, companion socket health, and native Windows subsystems.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: _isRunning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow),
                    label: const Text('Run Subsystem Diagnostics'),
                    onPressed: isConnected && !_isRunning ? _runFullDiagnostics : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_lastError != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('Error running diagnostics: $_lastError', style: const TextStyle(color: Colors.red)),
              ),
            ),

          if (_pingLatencyMs != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed, color: Colors.blue),
                title: const Text('WebSocket Ping Roundtrip Latency', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Roundtrip: $_pingLatencyMs ms (Local Wi-Fi)'),
                trailing: const Chip(
                  label: Text('PASS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.green,
                ),
              ),
            ),

          const SizedBox(height: 8),

          if (_companionItems.isNotEmpty) ...[
            Text('Windows Companion Subsystem Health', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 8),
            ..._companionItems.map((item) {
              final sub = item['subsystem'] as String;
              final status = item['status'] as String;
              final msg = item['message'] as String;
              final details = item['details'] as String? ?? '';
              final isPass = status == 'PASS';

              return Card(
                child: ListTile(
                  leading: Icon(
                    isPass ? Icons.check_circle : Icons.error,
                    color: isPass ? Colors.green : Colors.red,
                  ),
                  title: Text(sub, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$msg\n$details'),
                  isThreeLine: details.isNotEmpty,
                  trailing: Chip(
                    label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    backgroundColor: isPass ? Colors.green : Colors.red,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
