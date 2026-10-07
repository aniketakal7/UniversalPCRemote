import 'package:flutter/material.dart';
import 'features/clipboard/clipboard_screen.dart';
import 'features/diagnostics/diagnostics_screen.dart';
import 'features/discovery/discovery_screen.dart';
import 'features/keyboard/keyboard_screen.dart';
import 'features/media/media_screen.dart';
import 'features/remotes/remotes_screen.dart';
import 'features/system/system_screen.dart';
import 'features/touchpad/touchpad_screen.dart';
import 'state/connection_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UniversalRemoteApp());
}

class UniversalRemoteApp extends StatefulWidget {
  const UniversalRemoteApp({super.key});

  @override
  State<UniversalRemoteApp> createState() => _UniversalRemoteAppState();
}

class _UniversalRemoteAppState extends State<UniversalRemoteApp> {
  final ConnectionStateManager _stateManager = ConnectionStateManager();
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void dispose() {
    _stateManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _stateManager,
      builder: (context, _) {
        return MaterialApp(
          title: 'Universal PC Remote',
          debugShowCheckedModeBanner: false,
          themeMode: _themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B82F6),
              brightness: Brightness.dark,
            ),
          ),
          home: HomeScreen(
            stateManager: _stateManager,
            isDarkMode: _themeMode == ThemeMode.dark,
            onToggleTheme: () {
              setState(() {
                _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              });
            },
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ConnectionStateManager stateManager;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.stateManager,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.stateManager.isConnected;

    final screens = [
      TouchpadScreen(stateManager: widget.stateManager),
      KeyboardScreen(stateManager: widget.stateManager),
      MediaScreen(stateManager: widget.stateManager),
      RemotesScreen(stateManager: widget.stateManager),
      SystemScreen(stateManager: widget.stateManager),
      ClipboardScreen(stateManager: widget.stateManager),
      DiscoveryScreen(stateManager: widget.stateManager),
      DiagnosticsScreen(stateManager: widget.stateManager),
    ];

    final titles = [
      'Touchpad & Mouse',
      'Keyboard Control',
      'Media Transport',
      'Application Remotes',
      'System & Power',
      'Clipboard Sync',
      'PC Discovery & Pairing',
      'Diagnostics',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[_currentIndex], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isConnected
                      ? '${widget.stateManager.connectedPcName} (${widget.stateManager.activeIp})'
                      : 'Offline / Disconnected',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: Icon(
              Icons.wifi_tethering,
              color: isConnected ? Colors.green : Colors.grey,
            ),
            tooltip: 'Discovery & Devices',
            onPressed: () {
              setState(() => _currentIndex = 6);
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex.clamp(0, 4),
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.touch_app), label: 'Touchpad'),
          NavigationDestination(icon: Icon(Icons.keyboard), label: 'Keyboard'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Media'),
          NavigationDestination(icon: Icon(Icons.apps), label: 'Remotes'),
          NavigationDestination(icon: Icon(Icons.power_settings_new), label: 'System'),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.settings_remote, size: 36),
                  const SizedBox(height: 8),
                  const Text('Universal PC Remote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    isConnected ? 'Connected to ${widget.stateManager.connectedPcName}' : 'No PC connected',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.touch_app),
              title: const Text('Touchpad & Mouse'),
              selected: _currentIndex == 0,
              onTap: () {
                setState(() => _currentIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.keyboard),
              title: const Text('Keyboard Control'),
              selected: _currentIndex == 1,
              onTap: () {
                setState(() => _currentIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Media Controller'),
              selected: _currentIndex == 2,
              onTap: () {
                setState(() => _currentIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.apps),
              title: const Text('Application Remotes & Macros'),
              selected: _currentIndex == 3,
              onTap: () {
                setState(() => _currentIndex = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.power_settings_new),
              title: const Text('System & Power'),
              selected: _currentIndex == 4,
              onTap: () {
                setState(() => _currentIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('Clipboard Synchronization'),
              selected: _currentIndex == 5,
              onTap: () {
                setState(() => _currentIndex = 5);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.wifi_find),
              title: const Text('PC Discovery & Pairing'),
              selected: _currentIndex == 6,
              onTap: () {
                setState(() => _currentIndex = 6);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: const Text('Diagnostics & Latency'),
              selected: _currentIndex == 7,
              onTap: () {
                setState(() => _currentIndex = 7);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
