import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/strings.dart';

/// Local (on-device) notifications for new chat messages while the app runs
/// in the background. Push while the app is closed needs Firebase Cloud
/// Messaging, which is not set up.
abstract class LocalNotifier {
  /// Sets up the plugin; [onTap] gets the payload of a tapped notification.
  Future<void> init(void Function(String payload) onTap);

  /// The payload of the notification that launched the app, if any.
  Future<String?> launchPayload();

  Future<void> showMessage({
    required int chatId,
    required String title,
    required String body,
  });

  Future<void> cancelChat(int chatId);

  /// Android 13+ asks for permission. Null = the platform has no such
  /// permission (nothing to ask).
  Future<bool?> permissionGranted();

  Future<bool> requestPermission();
}

/// The payload of a chat notification.
String chatPayload(int chatId) => 'chat:$chatId';

/// The chat id in a payload, or null.
int? chatIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith('chat:')) return null;
  return int.tryParse(payload.substring(5));
}

/// Does nothing (web, tests).
class NoopLocalNotifier implements LocalNotifier {
  const NoopLocalNotifier();

  @override
  Future<void> init(void Function(String payload) onTap) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<void> showMessage({
    required int chatId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelChat(int chatId) async {}

  @override
  Future<bool?> permissionGranted() async => null;

  @override
  Future<bool> requestPermission() async => false;
}

/// flutter_local_notifications on Android.
class AndroidLocalNotifier implements LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'chat_messages',
    S.notifChannel,
    channelDescription: S.notifChannelText,
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.message,
    color: Color(0xFFD7263D),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init(void Function(String payload) onTap) async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
        ),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) onTap(p);
        },
      );
      _ready = true;
    } catch (e) {
      debugPrint('local notifications: $e');
    }
  }

  @override
  Future<String?> launchPayload() async {
    if (!_ready) return null;
    try {
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d == null || !d.didNotificationLaunchApp) return null;
      return d.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> showMessage({
    required int chatId,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: chatId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: _channel),
        payload: chatPayload(chatId),
      );
    } catch (e) {
      debugPrint('local notifications: $e');
    }
  }

  @override
  Future<void> cancelChat(int chatId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: chatId);
    } catch (_) {}
  }

  @override
  Future<bool?> permissionGranted() async {
    if (!_ready) return null;
    try {
      return await _android?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// The notifier for this platform: the plugin on Android, nothing elsewhere.
LocalNotifier platformLocalNotifier() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
    ? AndroidLocalNotifier()
    : const NoopLocalNotifier();
