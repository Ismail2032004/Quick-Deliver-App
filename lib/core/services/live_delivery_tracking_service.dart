import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/customer/domain/models/delivery_order.dart';
import '../../features/operations/presentation/controllers/delivery_hub_controller.dart';
import '../models/app_user.dart';
import '../supabase/providers/supabase_client_provider.dart';
import '../utils/order_workflow.dart';
import 'android_native_tracking_bridge.dart';
import 'location_service.dart';
import 'notification_service.dart';

final liveDeliveryTrackingServiceProvider =
    ChangeNotifierProvider<LiveDeliveryTrackingService>((ref) {
      final service = LiveDeliveryTrackingService(
        locationService: ref.read(locationServiceProvider),
        nativeTrackingBridge: ref.read(androidNativeTrackingBridgeProvider),
        readCurrentUser: () => ref.read(authControllerProvider).currentUser,
        readCurrentSession: () => AppConfig.isSupabaseConfigured
            ? ref.read(supabaseClientProvider).auth.currentSession
            : null,
        resolveOrderById: (orderId) async {
          final orders = ref.read(deliveryHubProvider).orders;
          for (final order in orders) {
            if (order.id == orderId) {
              return order;
            }
          }
          return null;
        },
        updateLocation: ({
          required String riderId,
          required String riderName,
          required double latitude,
          required double longitude,
          required String orderId,
          required bool isActive,
        }) {
          return ref
              .read(deliveryHubProvider.notifier)
              .updateRiderLocation(
                riderId: riderId,
                riderName: riderName,
                latitude: latitude,
                longitude: longitude,
                orderId: orderId,
                isActive: isActive,
              );
        },
        showTrackingNotification: ({
          required String title,
          required String body,
        }) {
          return ref
              .read(notificationServiceProvider)
              .showLiveTrackingNotification(title: title, body: body);
        },
        cancelTrackingNotification: () {
          return ref
              .read(notificationServiceProvider)
              .cancelLiveTrackingNotification();
        },
      );
      Future<void>.microtask(service.initialize);
      ref.listen(
        deliveryHubProvider.select((state) => state.orders),
        (_, next) => service.syncTrackedOrder(next),
      );
      ref.listen(
        authControllerProvider.select((value) => value.currentUser),
        (_, next) {
          if (next == null) {
            unawaited(service.stopTracking(markInactive: true));
            return;
          }
          unawaited(service.retryRestoreIfNeeded());
        },
      );
      ref.onDispose(service.dispose);
      return service;
    });

class LiveDeliveryTrackingService extends ChangeNotifier
    with WidgetsBindingObserver {
  LiveDeliveryTrackingService({
    required LocationService locationService,
    required AndroidNativeTrackingBridge nativeTrackingBridge,
    required AppUser? Function() readCurrentUser,
    required Session? Function() readCurrentSession,
    required Future<DeliveryOrder?> Function(String orderId) resolveOrderById,
    required Future<void> Function({
      required String riderId,
      required String riderName,
      required double latitude,
      required double longitude,
      required String orderId,
      required bool isActive,
    })
    updateLocation,
    required Future<void> Function({
      required String title,
      required String body,
    })
    showTrackingNotification,
    required Future<void> Function() cancelTrackingNotification,
  }) : _locationService = locationService,
       _nativeTrackingBridge = nativeTrackingBridge,
       _readCurrentUser = readCurrentUser,
       _readCurrentSession = readCurrentSession,
       _resolveOrderById = resolveOrderById,
       _updateLocation = updateLocation {
    _showTrackingNotification = showTrackingNotification;
    _cancelTrackingNotification = cancelTrackingNotification;
    WidgetsBinding.instance.addObserver(this);
  }

  final LocationService _locationService;
  final AndroidNativeTrackingBridge _nativeTrackingBridge;
  final AppUser? Function() _readCurrentUser;
  final Session? Function() _readCurrentSession;
  final Future<DeliveryOrder?> Function(String orderId) _resolveOrderById;
  final Future<void> Function({
    required String riderId,
    required String riderName,
    required double latitude,
    required double longitude,
    required String orderId,
    required bool isActive,
  })
  _updateLocation;
  late final Future<void> Function({
    required String title,
    required String body,
  })
  _showTrackingNotification;
  late final Future<void> Function() _cancelTrackingNotification;

  static const _activeOrderPreferenceKey =
      'quickdeliver.live_tracking.active_order_id';

  StreamSubscription<LiveLocationUpdate>? _locationSubscription;
  DeliveryOrder? _activeOrder;
  SharedPreferences? _prefs;
  DateTime? _lastSentAt;
  LiveLocationUpdate? _lastSentLocation;
  String? _lastError;
  String? _statusMessage;
  String? _pendingRestoreOrderId;
  bool _isTracking = false;
  bool _isPausedByLifecycle = false;
  bool _isRunningInBackground = false;
  bool _initialized = false;
  bool _isRestoring = false;

  bool get isTracking => _isTracking;
  bool get isPausedByLifecycle => _isPausedByLifecycle;
  bool get isRunningInBackground => _isRunningInBackground;
  String? get lastError => _lastError;
  String? get statusMessage => _statusMessage;
  String? get activeOrderId => _activeOrder?.id;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    _pendingRestoreOrderId = _prefs?.getString(_activeOrderPreferenceKey);
    _initialized = true;
    if (_useNativeAndroidTracking) {
      final status = await _nativeTrackingBridge.getStatus();
      if (status.isActive && status.orderId != null) {
        _pendingRestoreOrderId = status.orderId;
        _isTracking = false;
        _statusMessage = status.riderGuidance;
      } else if (status.lastError != null) {
        _lastError = status.lastError;
      }
    }
    await _attemptRestoreTracking();
  }

  Future<void> startTracking(
    DeliveryOrder order, {
    bool recovered = false,
  }) async {
    if (!canPublishRiderLocation(order)) {
      throw const LocationServiceException(
        'Live rider tracking can only run while an assigned delivery is still active.',
      );
    }
    if (order.riderId == null || order.riderName == null) {
      throw const LocationServiceException(
        'Assign a rider before starting live delivery tracking.',
      );
    }
    final currentUser = _readCurrentUser();
    if (currentUser == null || currentUser.id != order.riderId) {
      throw const LocationServiceException(
        'Only the assigned rider can start live delivery tracking for this delivery.',
      );
    }

    if (_activeOrder?.id == order.id && _isTracking) {
      return;
    }

    await initialize();
    if (_useNativeAndroidTracking) {
      final existingStatus = await _nativeTrackingBridge.getStatus();
      if (existingStatus.isActive &&
          existingStatus.orderId == order.id &&
          recovered) {
        _activeOrder = order;
        _isTracking = true;
        _isPausedByLifecycle = false;
        _isRunningInBackground = false;
        _lastError = existingStatus.lastError;
        _statusMessage = existingStatus.riderGuidance ??
            'Native Android tracking is active for this delivery.';
        notifyListeners();
        return;
      }
    }
    await stopTracking(markInactive: _activeOrder?.id != order.id);
    _activeOrder = order;
    _lastError = null;
    _isPausedByLifecycle = false;
    _isRunningInBackground = false;
    _isTracking = true;
    _statusMessage = recovered
        ? 'Live tracking resumed automatically for this active delivery.'
        : 'Live tracking is active for this delivery.';
    await _persistActiveOrderId(order.id);
    final guidance = await _locationService.riderBackgroundTrackingGuidance();
    if (guidance != null) {
      _statusMessage = guidance;
    }
    notifyListeners();

    if (_useNativeAndroidTracking) {
      final session = _readCurrentSession();
      if (session == null || session.accessToken.isEmpty) {
        _isTracking = false;
        throw const LocationServiceException(
          'An authenticated Supabase session is required before native rider tracking can start.',
        );
      }
      final status = await _nativeTrackingBridge.startTracking(
        supabaseUrl: AppConfig.supabaseUrl,
        supabaseAnonKey: AppConfig.supabaseAnonKey,
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        riderId: order.riderId!,
        riderName: order.riderName!,
        orderId: order.id,
      );
      _isTracking = status.isActive;
      _lastError = status.lastError;
      _statusMessage =
          status.riderGuidance ??
          'Native Android tracking is active for this delivery.';
      _isRunningInBackground = false;
      notifyListeners();
      if (!_isTracking && _lastError != null) {
        throw LocationServiceException(_lastError!);
      }
      return;
    }

    await _refreshTrackingNotification();

    final current = await _locationService.getCurrentLiveLocation();
    await _publish(order, current, force: true);
    _locationSubscription = _locationService
        .liveLocationStream(distanceFilter: 15)
        .listen(
          (update) => unawaited(_publish(order, update)),
          onError: (Object error) {
            _lastError = error.toString();
            notifyListeners();
          },
        );
  }

  Future<void> stopTracking({bool markInactive = false}) async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    final order = _activeOrder;
    if (_useNativeAndroidTracking) {
      final status = await _nativeTrackingBridge.stopTracking(
        markInactive: markInactive,
      );
      _lastError = status.lastError;
    } else if (markInactive &&
        order != null &&
        order.riderId != null &&
        order.riderName != null &&
        _lastSentLocation != null) {
      await _updateLocation(
        riderId: order.riderId!,
        riderName: order.riderName!,
        latitude: _lastSentLocation!.latitude,
        longitude: _lastSentLocation!.longitude,
        orderId: order.id,
        isActive: false,
      );
    }

    _activeOrder = null;
    _isTracking = false;
    _isPausedByLifecycle = false;
    _isRunningInBackground = false;
    _statusMessage = null;
    _pendingRestoreOrderId = null;
    await _persistActiveOrderId(null);
    if (!_useNativeAndroidTracking) {
      await _cancelTrackingNotification();
    }
    notifyListeners();
  }

  Future<void> sendSingleUpdate(DeliveryOrder order) async {
    if (!canPublishRiderLocation(order)) {
      throw const LocationServiceException(
        'This delivery is no longer eligible for live rider updates.',
      );
    }
    if (order.riderId == null || order.riderName == null) {
      throw const LocationServiceException(
        'Assign a rider before sending a live location update.',
      );
    }

    final current = await _locationService.getCurrentLiveLocation();
    await _publish(order, current, force: true);
  }

  Future<void> _publish(
    DeliveryOrder order,
    LiveLocationUpdate update, {
    bool force = false,
  }) async {
    if (order.riderId == null || order.riderName == null) {
      return;
    }

    final shouldSkip = !force && _shouldThrottle(update);
    if (shouldSkip) {
      return;
    }

    await _updateLocation(
      riderId: order.riderId!,
      riderName: order.riderName!,
      latitude: update.latitude,
      longitude: update.longitude,
      orderId: order.id,
      isActive: true,
    );

    _lastSentAt = DateTime.now();
    _lastSentLocation = update;
    _lastError = null;
    _statusMessage = _isRunningInBackground && _isAndroidPlatform
        ? 'Background tracking is active on Android for ${order.id}.'
        : 'Live rider location is updating for ${order.id}.';
    await _refreshTrackingNotification();
    notifyListeners();
  }

  bool _shouldThrottle(LiveLocationUpdate next) {
    final lastSentAt = _lastSentAt;
    final lastSentLocation = _lastSentLocation;
    if (lastSentAt == null || lastSentLocation == null) {
      return false;
    }

    final secondsSinceLastSend = DateTime.now().difference(lastSentAt).inSeconds;
    final movedMeters = Geolocator.distanceBetween(
      lastSentLocation.latitude,
      lastSentLocation.longitude,
      next.latitude,
      next.longitude,
    );
    return secondsSinceLastSend < 12 && movedMeters < 25;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final order = _activeOrder;
    if (order == null) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_isAndroidPlatform) {
        unawaited(_syncAndroidNativeStatus(orderIdHint: order.id));
        notifyListeners();
        return;
      }
      if (_isPausedByLifecycle) {
        _isPausedByLifecycle = false;
        notifyListeners();
        unawaited(startTracking(order, recovered: true));
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      if (_isAndroidPlatform) {
        _isRunningInBackground = true;
        _isPausedByLifecycle = false;
        _statusMessage = _useNativeAndroidTracking
            ? 'Native Android tracking is active in the foreground service. Keep the ongoing notification visible for better reliability.'
            : 'Android background tracking is active. Keep this notification visible for better reliability.';
        notifyListeners();
        if (!_useNativeAndroidTracking) {
          unawaited(_refreshTrackingNotification());
        }
        return;
      }
      _isPausedByLifecycle = true;
      _isTracking = false;
      notifyListeners();
      unawaited(_locationSubscription?.cancel() ?? Future<void>.value());
      _locationSubscription = null;
    }
  }

  Future<void> syncTrackedOrder(List<DeliveryOrder> orders) async {
    final activeOrder = _activeOrder;
    if (activeOrder != null) {
      DeliveryOrder? refreshed;
      for (final order in orders) {
        if (order.id == activeOrder.id) {
          refreshed = order;
          break;
        }
      }
      if (refreshed == null || !canPublishRiderLocation(refreshed)) {
        await stopTracking(markInactive: true);
        return;
      }
      _activeOrder = refreshed;
      if (_useNativeAndroidTracking) {
        await _syncAndroidNativeStatus(orderIdHint: refreshed.id);
      }
    }

    if (_pendingRestoreOrderId != null && (!_isTracking || _activeOrder == null)) {
      await _attemptRestoreTracking();
    }
  }

  Future<void> retryRestoreIfNeeded() async {
    if (_pendingRestoreOrderId != null && (!_isTracking || _activeOrder == null)) {
      await _attemptRestoreTracking();
    } else if (_useNativeAndroidTracking && _activeOrder != null) {
      await _syncAndroidNativeStatus(orderIdHint: _activeOrder!.id);
    }
  }

  Future<void> _attemptRestoreTracking() async {
    if (_isRestoring) {
      return;
    }
    final orderId = _pendingRestoreOrderId;
    if (orderId == null || orderId.isEmpty) {
      return;
    }
    final currentUser = _readCurrentUser();
    if (currentUser == null) {
      return;
    }

    _isRestoring = true;
    try {
      final order = await _resolveOrderById(orderId);
      if (order == null ||
          order.riderId != currentUser.id ||
          !canPublishRiderLocation(order)) {
        _pendingRestoreOrderId = null;
        await _persistActiveOrderId(null);
        return;
      }
      await startTracking(order, recovered: true);
      _pendingRestoreOrderId = null;
    } finally {
      _isRestoring = false;
    }
  }

  Future<void> _syncAndroidNativeStatus({String? orderIdHint}) async {
    if (!_useNativeAndroidTracking) {
      return;
    }
    final status = await _nativeTrackingBridge.getStatus();
    _isTracking = status.isActive;
    _isRunningInBackground = false;
    _lastError = status.lastError;
    _statusMessage = status.riderGuidance;
    final nativeOrderId = status.orderId ?? orderIdHint;
    if (status.isActive && nativeOrderId != null) {
      _pendingRestoreOrderId = nativeOrderId;
    } else if (!status.isActive && _activeOrder == null) {
      _pendingRestoreOrderId = null;
    }
    notifyListeners();
  }

  Future<void> _persistActiveOrderId(String? orderId) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    if (orderId == null || orderId.isEmpty) {
      await prefs.remove(_activeOrderPreferenceKey);
      return;
    }
    await prefs.setString(_activeOrderPreferenceKey, orderId);
  }

  Future<void> _refreshTrackingNotification() async {
    final order = _activeOrder;
    if (order == null) {
      return;
    }
    final body = _lastSentLocation == null
        ? 'Preparing live rider updates for ${order.id}.'
        : _isRunningInBackground && _isAndroidPlatform
        ? 'Background updates active for ${order.id}. Latest point ${_lastSentLocation!.latitude.toStringAsFixed(4)}, ${_lastSentLocation!.longitude.toStringAsFixed(4)}.'
        : 'Latest rider point ${_lastSentLocation!.latitude.toStringAsFixed(4)}, ${_lastSentLocation!.longitude.toStringAsFixed(4)}.';
    await _showTrackingNotification(
      title: 'QuickDeliver live tracking',
      body: body,
    );
  }

  bool get _isAndroidPlatform =>
      !kIsWeb && Platform.isAndroid;

  bool get _useNativeAndroidTracking =>
      _isAndroidPlatform &&
      AppConfig.isSupabaseConfigured &&
      _nativeTrackingBridge.isSupported;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    super.dispose();
  }
}
