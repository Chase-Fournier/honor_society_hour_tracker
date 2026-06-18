import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

class FirebaseMessagingService {
  FirebaseMessagingService._();
  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  bool _initialized = false;
  bool _firebaseAvailable = false;

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;

  Future<void> init({required Future<void> Function(String?) onTokenRefresh}) async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseAvailable = true;
    } catch (e) {
      debugPrint(
          'FirebaseMessagingService: Firebase not configured yet — push disabled. ($e)');
      _firebaseAvailable = false;
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      debugPrint('FCM foreground: ${n?.title}');
      if (n == null) return;
      NotificationService.instance.showLocal(
        id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title: n.title ?? 'Notification',
        body: n.body ?? '',
        // Encode as JSON so a tap on this notification decodes back to the
        // same data map used for routing.
        payload: message.data.isEmpty ? null : jsonEncode(message.data),
      );
    });

    // Tap on an OS-displayed FCM notification while the app was backgrounded.
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NotificationService.instance.handleTapData(message.data);
    });

    // Tap that cold-started the app from a terminated state.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      NotificationService.instance.handleTapData(initial.data);
    }

    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen(onTokenRefresh);
  }

  Future<void> requestIosPermission() async {
    if (!_firebaseAvailable) return;
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<String?> getToken() async {
    if (!_firebaseAvailable) return null;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final apns = await _waitForApnsToken();
        if (apns == null) {
          debugPrint(
              'FirebaseMessagingService: APNS token not available after wait — skipping FCM token fetch.');
          return null;
        }
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FirebaseMessagingService: getToken failed: $e');
      return null;
    }
  }

  Future<String?> _waitForApnsToken({
    Duration timeout = const Duration(seconds: 15),
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final token = await FirebaseMessaging.instance.getAPNSToken();
      if (token != null) return token;
      await Future.delayed(interval);
    }
    return null;
  }

  Future<void> deleteToken() async {
    if (!_firebaseAvailable) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('FirebaseMessagingService: deleteToken failed: $e');
    }
  }

  void dispose() {
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    _tokenRefreshSub?.cancel();
  }
}
