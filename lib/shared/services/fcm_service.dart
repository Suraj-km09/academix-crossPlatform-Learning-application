import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/firestore_paths.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FCMService {
  FCMService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'academix_high_importance',
    'Academix Notifications',
    description: 'Critical alerts for Academix users.',
    importance: Importance.high,
  );

  static bool _notificationsReady = false;
  static bool _foregroundHandlerReady = false;
  static bool _tokenRefreshReady = false;
  static bool _interactionHandlerReady = false;

  static GoRouter? _router;
  static String? _pendingRoute;

  static Future<void> initFCM() async {
    await _initializeLocalNotifications();
    await _requestPermissions();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _syncTokenForCurrentUser();
    refreshToken();
    setupForegroundHandler();

    _auth.authStateChanges().listen((_) {
      _syncTokenForCurrentUser();
    });
  }

  static Future<void> setupBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static void setupForegroundHandler() {
    if (_foregroundHandlerReady) {
      return;
    }
    _foregroundHandlerReady = true;
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  static Future<void> setupInteractionHandler(GoRouter router) async {
    _router = router;
    if (_pendingRoute != null && _pendingRoute!.trim().isNotEmpty) {
      final route = _pendingRoute!;
      _pendingRoute = null;
      Future<void>.microtask(() => _router?.go(route));
    }

    if (_interactionHandlerReady) {
      return;
    }
    _interactionHandlerReady = true;

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = _extractTargetRoute(message.data);
      _navigateToRoute(route);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final route = _extractTargetRoute(initialMessage.data);
      _navigateToRoute(route);
    }
  }

  static void refreshToken() {
    if (_tokenRefreshReady) {
      return;
    }
    _tokenRefreshReady = true;

    _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null || uid.trim().isEmpty || token.trim().isEmpty) {
        return;
      }
      await _saveToken(uid, token);
    });
  }

  static Future<String?> getToken() => _messaging.getToken();

  static Future<void> subscribeToTopic(String topic) {
    return _messaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) {
    return _messaging.unsubscribeFromTopic(topic);
  }

  static Future<void> _syncTokenForCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    await _saveToken(uid, token);
  }

  static Future<void> _saveToken(String uid, String token) async {
    await _firestore.collection(FirestorePaths.users).doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  static Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      provisional: false,
      criticalAlert: false,
      carPlay: false,
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_notificationsReady) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iOSSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iOSSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.trim().isEmpty) {
          return;
        }

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            final route = _extractTargetRoute(decoded);
            _navigateToRoute(route);
          }
        } catch (_) {
          // Ignore malformed payloads.
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    _notificationsReady = true;
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null || !_notificationsReady) {
      return;
    }

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static String _extractTargetRoute(Map<dynamic, dynamic> data) {
    final raw = (data['targetRoute'] ?? data['route'] ?? '').toString().trim();
    if (raw.isEmpty) {
      return '/notifications';
    }
    return raw;
  }

  static void _navigateToRoute(String route) {
    if (route.trim().isEmpty) {
      return;
    }

    if (_router == null) {
      _pendingRoute = route;
      return;
    }

    Future<void>.microtask(() {
      _router?.go(route);
    });
  }
}
