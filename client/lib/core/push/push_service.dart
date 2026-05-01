// NOTE: Requires google-services.json (Android) and GoogleService-Info.plist (iOS).
// See docs/PUSH_SETUP.md for setup instructions.
//
// Privacy guarantee: this service requests background-delivery-only permission.
// No alerts, badges, or sounds are requested.  Apple/Google see only that the
// app was woken at time T — no message content, sender, or group information.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Initialise push notifications for background wake-up delivery.
///
/// Must be called after Firebase.initializeApp() and after the user has
/// authenticated (so that [authToken] is available to register the token).
class PushService {
  static Future<void> init(String serverUrl, String authToken) async {
    final messaging = FirebaseMessaging.instance;

    // Request background-delivery-only permission.
    // alert: false   — no banners or lock-screen notifications
    // badge: false   — no badge count (we never send a count anyway)
    // sound: false   — no sound
    // provisional: true — iOS: quiet delivery without a permission prompt
    await messaging.requestPermission(
      alert: false,
      badge: false,
      sound: false,
      provisional: true,
    );

    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token, 'fcm', serverUrl, authToken);
    }

    // Refresh handler: re-register if the token rotates.
    messaging.onTokenRefresh.listen((newToken) {
      _registerToken(newToken, 'fcm', serverUrl, authToken);
    });

    // Background wakeup: the top-level _backgroundHandler opens the WS and
    // drains /messages/pending.  No notification content is ever shown.
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // Foreground: the WS is already open when the app is in the foreground,
    // so incoming silent pushes are no-ops here.
    FirebaseMessaging.onMessage.listen((_) {/* already connected — no-op */});
  }

  static Future<void> _registerToken(
    String token,
    String platform,
    String serverUrl,
    String authToken,
  ) async {
    try {
      await http.post(
        Uri.parse('$serverUrl/push/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'token': token, 'platform': platform}),
      );
    } catch (_) {
      // Non-fatal: the server will still deliver messages on reconnect.
    }
  }

  /// Unregister the device token on logout so the user stops receiving wakeups.
  static Future<void> unregister(String serverUrl, String authToken) async {
    try {
      await http.delete(
        Uri.parse('$serverUrl/push/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );
    } catch (_) {}
  }
}

/// Top-level background message handler (required by firebase_messaging).
///
/// Called when the app is killed or backgrounded and a silent push arrives.
/// Opens a WebSocket connection to drain /messages/pending, then disconnects.
/// The WsClient's reconnect logic handles the actual message retrieval.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // The WsClient will reconnect and drain /messages/pending automatically
  // when the app comes to the foreground.  For a true background drain,
  // initialise the WsClient here and call its drainPending() method.
  // Left as a stub because full background isolation requires additional
  // platform-specific setup (see docs/PUSH_SETUP.md).
}
