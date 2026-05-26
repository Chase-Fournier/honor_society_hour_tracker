import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'firebase_messaging_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _channelEventReminders = 'event_reminders';
  static const String _channelGeneral = 'general';

  static const String _prefsKeyTokenSynced = 'fcm_token_last_synced_user';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (e) {
      debugPrint('NotificationService: failed to resolve local timezone: $e');
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );

    await _plugin.initialize(settings);
    await _createAndroidChannels();

    await FirebaseMessagingService.instance.init(onTokenRefresh: syncFcmToken);
  }

  Future<void> _createAndroidChannels() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      _channelEventReminders,
      'Event Reminders',
      description: 'Reminders before events you signed up for.',
      importance: Importance.high,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _channelGeneral,
      'General',
      description:
          'Meeting notes, hour updates, swap requests, and other alerts.',
      importance: Importance.defaultImportance,
    ));
  }

  Future<bool> requestPermissions() async {
    bool granted = true;

    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      await FirebaseMessagingService.instance.requestIosPermission();
    } else if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      granted = status.isGranted;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final exact = await android?.requestExactAlarmsPermission();
      if (exact == false) {
        debugPrint(
            'NotificationService: exact-alarm permission not granted, falling back to inexact.');
      }
    }

    return granted;
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return (await android?.areNotificationsEnabled()) ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final settings = await ios?.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return false;
  }

  Future<void> scheduleEventReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledFor,
    String? payload,
  }) async {
    final when = tz.TZDateTime.from(scheduledFor, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelEventReminders,
          'Event Reminders',
          channelDescription: 'Reminders before events you signed up for.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showLocal({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool important = false,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          important ? _channelEventReminders : _channelGeneral,
          important ? 'Event Reminders' : 'General',
          channelDescription: important
              ? 'Reminders before events you signed up for.'
              : 'Meeting notes, hour updates, swap requests, and other alerts.',
          importance:
              important ? Importance.high : Importance.defaultImportance,
          priority: important ? Priority.high : Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  Future<void> syncFcmToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lastKey = '${_prefsKeyTokenSynced}_${user.id}';
    if (prefs.getString(lastKey) == token) return;

    try {
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'platform': Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
                ? 'android'
                : 'other',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'fcm_token');
      await prefs.setString(lastKey, token);
    } catch (e) {
      debugPrint('NotificationService: failed to sync FCM token: $e');
    }
  }

  Future<void> registerForPush() async {
    final token = await FirebaseMessagingService.instance.getToken();
    await syncFcmToken(token);
  }

  Future<void> unregisterDevice() async {
    final token = await FirebaseMessagingService.instance.getToken();
    if (token == null) return;
    try {
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('fcm_token', token);
    } catch (e) {
      debugPrint('NotificationService: failed to remove FCM token: $e');
    }
  }
}
