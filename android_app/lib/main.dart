import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'core/app_haptics.dart';
import 'core/app_theme.dart';
import 'features/clipboard/clipboard_screen.dart';
import 'features/diagnostics/diagnostics_screen.dart';
import 'features/discovery/discovery_screen.dart';
import 'features/keyboard/keyboard_screen.dart';
import 'features/media/media_screen.dart';
import 'features/remotes/remotes_screen.dart';
import 'features/system/system_screen.dart';
import 'features/touchpad/touchpad_screen.dart';
import 'services/remote_foreground_service.dart';
import 'state/connection_state.dart';
import 'widgets/glass_card.dart';
import 'widgets/status_pill.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBg,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  unawaited(RemoteForegroundService.init());
  unawaited(AppHaptics.init());
  runApp(const UniversalRemoteApp());
}

class UniversalRemoteApp extends StatefulWidget {
  const UniversalRemoteApp({super.key});

  @override
  State<UniversalRemoteApp> createState() => _UniversalRemoteAppState();
}

class _UniversalRemoteAppState extends State<UniversalRemoteApp> with WidgetsBindingObserver {
  final ConnectionStateManager _stateManager = ConnectionStateManager();
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_stateManager.reconnectOnResume());
    }
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
          theme: AppTheme.getLightTheme(),
          darkTheme: AppTheme.getDarkTheme(),
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
  bool _wasConnected = false;
  final TextEditingController _globalPinController = TextEditingController();

  final List<String> _titles = [
    'Touchpad & Mouse',
    'Keyboard & Shortcuts',
    'Media Transport Deck',
    'Application Remotes',
    'System & Workstation',
    'Clipboard Bridge',
    'PC Discovery & Link',
    'Diagnostics Benchmark',
  ];

  @override
  void initState() {
    super.initState();
    _wasConnected = widget.stateManager.isConnected;
    widget.stateManager.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    widget.stateManager.removeListener(_onConnectionChanged);
    _globalPinController.dispose();
    super.dispose();
  }

  void _onConnectionChanged() {
    if (!_wasConnected && widget.stateManager.isConnected) {
      setState(() {
        _currentIndex = 0; // Seamlessly jump to Touchpad on successful link
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Connected to ${widget.stateManager.displayName}! Trackpad ready.'),
            ],
          ),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    _wasConnected = widget.stateManager.isConnected;

    if (widget.stateManager.status == AppConnectionStatus.pairingRequired &&
        !widget.stateManager.isPairingDialogShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.stateManager.status == AppConnectionStatus.pairingRequired &&
            !widget.stateManager.isPairingDialogShowing) {
          _showGlobalPairingDialog();
        }
      });
    }
  }

  void _showGlobalPairingDialog() {
    if (widget.stateManager.isPairingDialogShowing || !mounted) return;
    widget.stateManager.isPairingDialogShowing = true;
    _globalPinController.clear();

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
                'Enter the 6-digit PIN displayed on ${widget.stateManager.displayName}:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _globalPinController,
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
                onSubmitted: (val) {
                  if (val.trim().length == 6) {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    _submitGlobalPin(val.trim());
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
              onPressed: () {
                final pin = _globalPinController.text.trim();
                if (pin.length == 6) {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  _submitGlobalPin(pin);
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

  Future<void> _submitGlobalPin(String pin) async {
    final ok = await widget.stateManager.submitPairingPin(pin);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.stateManager.errorMessage ?? 'Pairing failed. Incorrect PIN.'),
          backgroundColor: AppTheme.accentRose,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _showGlobalPairingDialog(),
          ),
        ),
      );
    }
  }

  void _showConnectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final isConnected = widget.stateManager.isConnected;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardElevated : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isConnected ? AppTheme.greenGradient : AppTheme.primaryGradient,
                    ),
                    child: Icon(
                      isConnected ? Icons.laptop_windows_rounded : Icons.wifi_find_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? widget.stateManager.displayName : 'No PC Linked',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          isConnected
                              ? 'Active LAN IP: ${widget.stateManager.activeIp}:51234'
                              : 'Tap below to scan Wi-Fi network',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.stateManager.status == AppConnectionStatus.pairingRequired) ...[
                const SizedBox(height: 16),
                TactileButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: 14,
                  gradient: const LinearGradient(colors: [AppTheme.accentAmber, Colors.deepOrangeAccent]),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showGlobalPairingDialog();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Enter Pairing PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TactileButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      borderRadius: 14,
                      gradient: AppTheme.primaryGradient,
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _currentIndex = 6); // Discovery Tab
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Network Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  if (isConnected) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TactileButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        borderRadius: 14,
                        backgroundColor: AppTheme.accentRose.withOpacity(0.15),
                        borderColor: AppTheme.accentRose,
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.stateManager.disconnect();
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.power_settings_new_rounded, color: AppTheme.accentRose, size: 18),
                            SizedBox(width: 8),
                            Text('Disconnect', style: TextStyle(color: AppTheme.accentRose, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAllToolsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardElevated : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Remote Control Suite',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _buildToolGridItem(0, Icons.touch_app_rounded, 'Touchpad', ctx),
                  _buildToolGridItem(1, Icons.keyboard_rounded, 'Keyboard', ctx),
                  _buildToolGridItem(2, Icons.graphic_eq_rounded, 'Media', ctx),
                  _buildToolGridItem(3, Icons.apps_rounded, 'Remotes', ctx),
                  _buildToolGridItem(4, Icons.power_settings_new_rounded, 'Power', ctx),
                  _buildToolGridItem(5, Icons.content_paste_rounded, 'Clipboard', ctx),
                  _buildToolGridItem(6, Icons.radar_rounded, 'Discovery', ctx),
                  _buildToolGridItem(7, Icons.speed_rounded, 'Diagnostics', ctx),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolGridItem(int index, IconData icon, String label, BuildContext sheetCtx) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pop(sheetCtx);
        setState(() => _currentIndex = index);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.2)
              : (isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : (isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppTheme.primaryLight : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryLight : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WithForegroundTask(
      child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_currentIndex],
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.2),
            ),
            const SizedBox(height: 4),
            StatusPill(
              stateManager: widget.stateManager,
              onTap: () => _showConnectionModal(context),
            ),
          ],
        ),
        actions: [
          // All Tools Quick Launcher
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, size: 22),
            tooltip: 'All Remote Tools',
            onPressed: () => _showAllToolsSheet(context),
          ),
          // Theme Toggle
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 22),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex.clamp(0, 4),
          onDestinationSelected: (idx) {
            setState(() => _currentIndex = idx);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.touch_app_outlined),
              selectedIcon: Icon(Icons.touch_app_rounded, color: AppTheme.primaryLight),
              label: 'Trackpad',
            ),
            NavigationDestination(
              icon: Icon(Icons.keyboard_outlined),
              selectedIcon: Icon(Icons.keyboard_rounded, color: AppTheme.primaryLight),
              label: 'Keyboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.graphic_eq_outlined),
              selectedIcon: Icon(Icons.graphic_eq_rounded, color: AppTheme.primaryLight),
              label: 'Media',
            ),
            NavigationDestination(
              icon: Icon(Icons.apps_outlined),
              selectedIcon: Icon(Icons.apps_rounded, color: AppTheme.primaryLight),
              label: 'Remotes',
            ),
            NavigationDestination(
              icon: Icon(Icons.power_settings_new_outlined),
              selectedIcon: Icon(Icons.power_settings_new_rounded, color: AppTheme.primaryLight),
              label: 'Power',
            ),
          ],
        ),
      ),
      drawer: Drawer(
        width: 320,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Universal PC Remote',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Crafted by Aniket Akal',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                  Text(
                    widget.stateManager.isConnected ? 'Connected & Ready' : 'Private PC Remote Suite',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            _buildDrawerTile(0, Icons.touch_app_rounded, 'Touchpad & Mouse'),
            _buildDrawerTile(1, Icons.keyboard_rounded, 'Keyboard & Hotkeys'),
            _buildDrawerTile(2, Icons.graphic_eq_rounded, 'Media Transport Deck'),
            _buildDrawerTile(3, Icons.apps_rounded, 'Application Remotes & Slides'),
            _buildDrawerTile(4, Icons.power_settings_new_rounded, 'System & Power Controls'),
            _buildDrawerTile(5, Icons.content_paste_rounded, 'Clipboard Synchronization'),
            Divider(color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder),
            _buildDrawerTile(6, Icons.radar_rounded, 'PC Discovery & Pairing'),
            _buildDrawerTile(7, Icons.speed_rounded, 'Latency Diagnostics Benchmark'),
            Divider(color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder),
            ListTile(
              leading: const Icon(Icons.help_outline_rounded, color: AppTheme.secondary),
              title: const Text('Quick Setup Guide & FAQ', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () => _showQuickGuideDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryLight),
              title: const Text('About Universal PC Remote', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () => _showAboutDialog(context),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded, color: AppTheme.primaryLight, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Developed by Aniket Akal',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                      ),
                    ),
                  ),
                  Text(
                    'v1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}

  void _showQuickGuideDialog(BuildContext context) {
    Navigator.pop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.help_outline_rounded, color: AppTheme.primaryLight, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Quick Setup Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGuideStep(
                  step: '1',
                  title: 'Connect to Same Wi-Fi',
                  desc: 'Ensure your phone and PC are connected to the same Wi-Fi router or mobile hotspot.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  step: '2',
                  title: 'Start Companion on PC',
                  desc: 'Run Universal PC Remote Companion on your Windows machine. It automatically broadcasts on port 5000.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  step: '3',
                  title: 'Pair with 6-Digit PIN',
                  desc: 'Tap your discovered PC on the Discovery page (or enter IP manually) and enter the 6-digit PIN shown on PC.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  step: '4',
                  title: 'Firewall Tip',
                  desc: 'If discovery fails, allow the Companion app through Windows Defender Firewall for Private Networks.',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({
    required String step,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: AppTheme.primaryLight,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    Navigator.pop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCardElevated : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Universal PC Remote',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'v1.0.0 Release',
                style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'A high-performance, ultra-low latency desktop remote control client featuring multi-touch trackpad, virtual keyboard, media deck, presentation remote, power controls, and real-time clipboard bridge.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkCardBorder : AppTheme.lightCardBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: AppTheme.secondary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '100% Local Peer-to-Peer • Zero Telemetry • No Cloud Servers',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(colors: [Color(0xFF171A23), Color(0xFF1E232F)])
                    : const LinearGradient(colors: [Color(0xFFF1F5F9), Color(0xFFFFFFFF)]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      gradient: AppTheme.purpleGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Created by Aniket Akal',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        Text(
                          'Lead Developer & Creator',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_rounded, color: AppTheme.primaryLight, size: 20),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(int index, IconData icon, String title) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryLight : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppTheme.primaryLight : null,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
    );
  }
}
