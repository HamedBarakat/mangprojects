import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles FCM token registration and foreground notification display.
///
/// Call [init] once after the user is authenticated.
/// The VAPID key is required for web; obtain it from:
/// Firebase Console → Project Settings → Cloud Messaging → Web Push certificates.
class FcmService {
  // TODO: Replace with the actual VAPID key from Firebase Console
  // Firebase Console → Project Settings → Cloud Messaging → Web Push certificates
  static const String _vapidKey =
      'REPLACE_WITH_YOUR_VAPID_KEY_FROM_FIREBASE_CONSOLE';

  static final FcmService _instance = FcmService._();
  FcmService._();
  factory FcmService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Call after the user signs in. Requests permission, fetches the FCM token,
  /// and persists it to Firestore under users/{uid}/fcmTokens/{token}.
  Future<void> init(String userId) async {
    // Skip web FCM until a real VAPID key is configured
    if (kIsWeb && _vapidKey.startsWith('REPLACE_WITH')) {
      debugPrint('[FCM] VAPID key not set — skipping web push notification setup');
      return;
    }

    try {
      // Request permission (required on iOS; shows a prompt on web first time)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permission denied — skipping token registration');
        return;
      }

      // Get the FCM token (web requires VAPID key)
      final token = kIsWeb
          ? await _messaging.getToken(vapidKey: _vapidKey)
          : await _messaging.getToken();

      if (token == null) {
        debugPrint('[FCM] Token is null — VAPID key may be missing or invalid');
        return;
      }

      debugPrint('[FCM] Token obtained: ${token.substring(0, 20)}…');
      await _saveToken(userId, token);

      // Refresh token when it rotates
      _messaging.onTokenRefresh.listen((newToken) {
        _saveToken(userId, newToken);
      });

      // Foreground message handling — show an in-app banner via overlay
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e) {
      debugPrint('[FCM] init error: $e');
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[FCM] Token saved for user $userId');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    debugPrint('[FCM] Foreground message: ${notification.title}');
    // Foreground display is handled by the app's existing in-app notification
    // bell (Firestore-based). No duplicate toast needed.
  }
}
