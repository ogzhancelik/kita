import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../feedback/toast_service.dart';
import '../network/api_client.dart';

/// Centralized service managing Firebase Cloud Messaging device tokens,
/// OS notification permissions, and incoming notification dispatch.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _isInitialized = false;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Initializes Firebase and configures notification stream handlers.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
      debugPrint('[PushNotificationService] Firebase initialized successfully');

      _setupMessageHandlers();
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to initialize Firebase: $e');
    }
  }

  /// Sets up foreground, background tap, and cold-start handlers.
  void _setupMessageHandlers() {
    // 1. Foreground message handler (when app is currently open and active)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[PushNotificationService] Foreground message received: ${message.data}');
      final title = message.notification?.title ?? message.data['title'];
      final body = message.notification?.body ?? message.data['body'];
      if (title != null && title.isNotEmpty) {
        KitaToast.show(
          message: '$title${body != null && body.isNotEmpty ? ': $body' : ''}',
          type: ToastType.info,
        );
      }
    });

    // 2. Notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[PushNotificationService] Notification opened from background: ${message.data}');
      _handleNotificationPayload(message.data);
    });

    // 3. Cold start initial message (when app was terminated and opened via tap)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[PushNotificationService] Cold start message detected: ${message.data}');
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationPayload(message.data);
        });
      }
    }).catchError((err) {
      debugPrint('[PushNotificationService] Error querying initial message: $err');
    });
  }

  /// Requests notification permissions and registers the FCM device token with backend.
  Future<void> registerDeviceToken() async {
    if (!_isInitialized) {
      await initialize();
    }
    if (!_isInitialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request notification permissions (Android 13+ & iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('[PushNotificationService] Notification permission declined');
        return;
      }

      // 2. Obtain device token (VAPID key required for Web)
      // ignore: deprecated_member_use
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? DefaultFirebaseOptions.vapidKey : null,
      );

      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        await _sendTokenToBackend(token);
      }

      // 3. Listen for token rotation
      _tokenRefreshSub?.cancel();
      // ignore: deprecated_member_use
      _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        _sendTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint('[PushNotificationService] Error registering device token: $e');
    }
  }

  /// Sends the device token to POST /api/users/device-token.
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final platformStr = kIsWeb
          ? 'web'
          : (Platform.isAndroid
              ? 'android'
              : (Platform.isIOS ? 'ios' : 'unknown'));

      await ApiClient().dio.post(
        '/api/users/device-token',
        data: {
          'token': token,
          'platform': platformStr,
        },
      );
      debugPrint('[PushNotificationService] Device token registered with backend');
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to send token to backend: $e');
    }
  }

  /// Unregisters the current device token on user logout.
  Future<void> unregisterDeviceToken() async {
    if (_currentToken == null) return;
    try {
      await ApiClient().dio.delete(
        '/api/users/device-token',
        data: {'token': _currentToken},
      );
      debugPrint('[PushNotificationService] Device token unregistered');
      _currentToken = null;
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to unregister token: $e');
    }
  }

  /// Routes payload to the appropriate screen upon notification tap.
  void _handleNotificationPayload(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    final type = data['type'];
    debugPrint('[PushNotificationService] Handling notification click payload: $type');

    // Room join notification: opponent joined custom room while host was outside
    // The WebSocket connection automatically transitions into ReadyPhaseScreen upon reconnect.
  }
}
