import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> quickDeliverBackgroundMessageHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Keep background push optional when Firebase config is missing.
  }
}

class FirebaseMessagingService {
  const FirebaseMessagingService();

  Future<bool> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        return false;
      }
      FirebaseMessaging.onBackgroundMessage(quickDeliverBackgroundMessageHandler);
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> requestTokenSafely() async {
    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<RemoteMessage?> getInitialMessageSafely() async {
    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }
      return FirebaseMessaging.instance.getInitialMessage();
    } catch (_) {
      return null;
    }
  }

  Stream<RemoteMessage> get onMessage {
    if (Firebase.apps.isEmpty) {
      return const Stream<RemoteMessage>.empty();
    }
    return FirebaseMessaging.onMessage;
  }

  Stream<RemoteMessage> get onMessageOpenedApp {
    if (Firebase.apps.isEmpty) {
      return const Stream<RemoteMessage>.empty();
    }
    return FirebaseMessaging.onMessageOpenedApp;
  }

  Stream<String> get onTokenRefresh {
    if (Firebase.apps.isEmpty) {
      return const Stream<String>.empty();
    }
    return FirebaseMessaging.instance.onTokenRefresh;
  }
}
