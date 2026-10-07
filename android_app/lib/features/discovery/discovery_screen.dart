import 'package:flutter/material.dart';
import '../../discovery/udp_discovery.dart';
import '../../state/connection_state.dart';

class DiscoveryScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;

  const DiscoveryScreen({super.key, required this.stateManager});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final TextEditingController _manualIpController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto start discovery on entering screen
    widget.stateManager.startDiscovery();
  }

  void _showPairingDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.amber),
            SizedBox(width: 8),
            Text('Enter Pairing PIN'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A 6-digit code is displayed on your PC screen.\nEnter it below to complete pairing:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                counterText: '',
                border: OutlineInputBorder(),
                hintText: '000000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.stateManager.disconnect();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final pin = _pinController.text.trim();
              if (pin.length == 6) {
                Navigator.pop(ctx);
                final ok = await widget.stateManager.submitPairingPin(pin);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.stateManager.errorMessage ?? 'Pairing failed.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Pair Device'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.stateManager.status;
    final isConnected = widget.stateManager.isConnected;

    // If pairing required, trigger dialog
    if (status == AppConnectionStatus.pairingRequired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPairingDialog();
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection Status Card
          Card(
            color: isConnected ? Colors.green.shade50.withOpacity(0.4) : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.check_circle : Icons.wifi_find,
                    color: isConnected ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected
                              ? 'Connected to ${widget.stateManager.connectedPcName}'
                              : 'Status: ${status.name.toUpperCase()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          isConnected
                              ? 'IP: ${widget.stateManager.activeIp}:51234'
                              : (widget.stateManager.errorMessage ?? 'Searching local Wi-Fi network...'),
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.stateManager.errorMessage != null ? Colors.red : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isConnected)
                    OutlinedButton(
                      onPressed: () => widget.stateManager.disconnect(),
                      child: const Text('Disconnect'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Discovered PCs Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discovered Windows PCs',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Scan Network',
                onPressed: () {
                  widget.stateManager.discovery.sendQuery();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          StreamBuilder<List<DiscoveredPC>>(
            stream: widget.stateManager.discovery.discoveredPCsStream,
            initialData: widget.stateManager.discovery.currentPCs,
            builder: (context, snapshot) {
              final pcs = snapshot.data ?? [];
              if (pcs.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(height: 12),
                          const Text('Listening for companion beacons on LAN...'),
                          const SizedBox(height: 6),
                          Text(
                            'Ensure the companion app is running on your PC.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: pcs.map((pc) {
                  final isCurrent = widget.stateManager.activeIp == pc.ipAddress && isConnected;

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.computer)),
                      title: Text(pc.pcName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${pc.ipAddress}:${pc.port} • ${pc.os}'),
                      trailing: FilledButton.tonal(
                        onPressed: isCurrent
                            ? null
                            : () => widget.stateManager.connectToPC(pc.ipAddress, pc.port, pc.pcName),
                        child: Text(isCurrent ? 'CONNECTED' : 'CONNECT'),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // Manual IP Connection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manual IP Connection',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'If UDP broadcast is blocked by your router, enter the IP shown on the PC companion window:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualIpController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 192.168.1.100',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.datetime,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final ip = _manualIpController.text.trim();
                          if (ip.isNotEmpty) {
                            widget.stateManager.connectToPC(ip);
                          }
                        },
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Paired Devices List
          Text(
            'Saved Paired Computers',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          widget.stateManager.pairing.pairedPcs.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('(No computers paired yet. Connect above to pair.)', style: TextStyle(color: Colors.grey)),
                  ),
                )
              : Column(
                  children: widget.stateManager.pairing.pairedPcs.map((p) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.verified_user, color: Colors.blue),
                        title: Text(p.pcName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('IP: ${p.ip} • Paired: ${p.pairedAt.toString().substring(0, 10)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Forget Device',
                          onPressed: () async {
                            await widget.stateManager.pairing.forgetDevice(p.ip);
                            setState(() {});
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}
