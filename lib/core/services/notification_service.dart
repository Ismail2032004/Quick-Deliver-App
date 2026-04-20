import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../config/app_config.dart';
import '../models/app_role.dart';
import '../router/app_router.dart';
import '../supabase/providers/supabase_client_provider.dart';
import '../supabase/supabase_tables.dart';
import 'firebase_messaging_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    ref: ref,
    firebaseMessagingService: const FirebaseMessagingService(),
  );
  ref.onDispose(service.dispose);
  return service;
});

class NotificationService {
  NotificationService({
    required Ref ref,
    required FirebaseMessagingService firebaseMessagingService,
  }) : _ref = ref,
       _firebaseMessagingService = firebaseMessagingService,
       _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'quickdeliver_orders';
  static const _trackingChannelId = 'quickdeliver_live_tracking';
  static const _trackingNotificationId = 42042;

  final Ref _ref;
  final FirebaseMessagingService _firebaseMessagingService;
  final FlutterLocalNotificationsPlugin _plugin;

  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool _initialized = false;
  bool _pushAvailable = false;
  int _nextNotificationId = 1;
  String? _deviceToken;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _initializeLocalNotifications();
    _pushAvailable = await _firebaseMessagingService.initialize();
    if (_pushAvailable) {
      _foregroundMessageSubscription = _firebaseMessagingService.onMessage.listen(
        (message) => unawaited(_showRemoteMessage(message)),
      );
      _openedMessageSubscription = _firebaseMessagingService.onMessageOpenedApp
          .listen((message) => unawaited(_handleRemoteMessageTap(message)));
      _tokenRefreshSubscription = _firebaseMessagingService.onTokenRefresh.listen(
        (token) {
          _deviceToken = token;
          final currentUserId = _ref.read(authControllerProvider).currentUser?.id;
          unawaited(
            syncPushRegistration(currentUserId: currentUserId),
          );
        },
      );
      final initialMessage = await _firebaseMessagingService.getInitialMessageSafely();
      if (initialMessage != null) {
        await _handleRemoteMessageTap(initialMessage);
      }
      _deviceToken = await _firebaseMessagingService.requestTokenSafely();
    }

    _initialized = true;
  }

  Future<void> syncPushRegistration({
    String? previousUserId,
    String? currentUserId,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      return;
    }

    await initialize();

    if (previousUserId != null &&
        previousUserId.isNotEmpty &&
        previousUserId != currentUserId) {
      await _setDeviceRegistration(
        userId: previousUserId,
        isActive: false,
      );
    }

    if (currentUserId == null || currentUserId.isEmpty) {
      return;
    }

    if (_deviceToken == null || _deviceToken!.isEmpty) {
      _deviceToken = await _firebaseMessagingService.requestTokenSafely();
    }

    if (_deviceToken == null || _deviceToken!.isEmpty) {
      return;
    }

    await _setDeviceRegistration(
      userId: currentUserId,
      isActive: true,
    );
  }

  Future<void> showOrderUpdate({
    required String title,
    required String body,
    String? orderId,
  }) async {
    await initialize();
    final payload = jsonEncode(<String, String>{
      if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
    });
    await _plugin.show(
      _nextNotificationId++,
      title,
      body,
      _notificationDetails,
      payload: payload == '{}' ? null : payload,
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        unawaited(_handlePayload(response.payload));
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'QuickDeliver Orders',
      description: 'Order status updates and rider events',
      importance: Importance.high,
    );
    const trackingChannel = AndroidNotificationChannel(
      _trackingChannelId,
      'QuickDeliver Live Tracking',
      description: 'Ongoing rider tracking updates while a delivery is active',
      importance: Importance.low,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(trackingChannel);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'QuickDeliver Orders',
      channelDescription: 'Order status updates and rider events',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> showLiveTrackingNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    await _plugin.show(
      _trackingNotificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _trackingChannelId,
          'QuickDeliver Live Tracking',
          channelDescription:
              'Ongoing rider tracking updates while a delivery is active',
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.service,
          ongoing: true,
          onlyAlertOnce: true,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
  }

  Future<void> cancelLiveTrackingNotification() async {
    await _plugin.cancel(_trackingNotificationId);
  }

  Future<void> _showRemoteMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title == null || body == null) {
      return;
    }
    await showOrderUpdate(
      title: title,
      body: body,
      orderId: message.data['orderId']?.toString(),
    );
  }

  Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    await _openOrderFromPayload(
      orderId: message.data['orderId']?.toString(),
    );
  }

  Future<void> _handlePayload(String? payload) async {
    if (payload == null || payload.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      await _openOrderFromPayload(orderId: decoded['orderId']?.toString());
    } catch (_) {
      // Ignore malformed payloads so notification taps never crash the app.
    }
  }

  Future<void> _openOrderFromPayload({String? orderId}) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      return;
    }

    final auth = _ref.read(authControllerProvider);
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      GoRouter.of(context).go(AppRoutes.login);
      return;
    }

    if (orderId == null || orderId.isEmpty) {
      final fallbackRoute = switch (currentUser.role) {
        AppRole.customer => AppRoutes.customerDashboard,
        AppRole.rider => AppRoutes.riderDashboard,
        AppRole.owner => AppRoutes.ownerDashboard,
      };
      GoRouter.of(context).go(fallbackRoute);
      return;
    }

    final route = switch (currentUser.role) {
      AppRole.customer => '${AppRoutes.customerOrderDetail}/$orderId',
      AppRole.rider => '${AppRoutes.riderDeliveryDetail}/$orderId',
      AppRole.owner => AppRoutes.ownerDashboard,
    };
    GoRouter.of(context).go(route);
  }

  Future<void> _setDeviceRegistration({
    required String userId,
    required bool isActive,
  }) async {
    final token = _deviceToken;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _ref
          .read(supabaseClientProvider)
          .from(SupabaseTables.pushDevices)
          .upsert({
            'token': token,
            'user_id': userId,
            'platform': _platformLabel,
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
            'last_seen_at': DateTime.now().toIso8601String(),
          }, onConflict: 'token');
    } catch (_) {
      // Keep push registration as a graceful best-effort path.
    }
  }

  String get _platformLabel {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  void dispose() {
    _foregroundMessageSubscription?.cancel();
    _openedMessageSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
  }
}
