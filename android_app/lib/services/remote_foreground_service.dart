import 'dart:async';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// Top-level entry point callback for background isolate
@pragma('vm:entry-point')
void remoteTaskCallback() {
  FlutterForegroundTask.setTaskHandler(RemoteTaskHandler());
}

class RemoteTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    // Send action ID to main isolate
    FlutterForegroundTask.sendDataToMain({'action': id});
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

class RemoteForegroundService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    FlutterForegroundTask.initCommunicationPort();

    if (Platform.isAndroid) {
      final NotificationPermission perm =
          await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'universal_pc_remote_bg',
        channelName: 'PC Remote Background Connection',
        channelDescription:
            'Keeps remote connection active in background and provides lock-screen media controls',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        allowWakeLock: true,
        allowWifiLock: true,
        stopWithTask: true,
      ),
    );

    _initialized = true;
  }

  static Future<void> startService({
    required String pcName,
    required String host,
  }) async {
    if (!Platform.isAndroid) return;
    await init();

    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Connected to $pcName',
        notificationText: 'Remote Active • $host',
        notificationButtons: _mediaButtons,
      );
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 5123,
      notificationTitle: 'Connected to $pcName',
      notificationText: 'Remote Active • $host',
      notificationButtons: _mediaButtons,
      callback: remoteTaskCallback,
    );
  }

  static Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      await FlutterForegroundTask.stopService();
    }
  }

  static const List<NotificationButton> _mediaButtons = [
    NotificationButton(id: 'btn_prev', text: '⏮ Prev'),
    NotificationButton(id: 'btn_play', text: '⏯ Play'),
    NotificationButton(id: 'btn_next', text: '⏭ Next'),
    NotificationButton(id: 'btn_vol_up', text: '🔊 Vol+'),
  ];
}
