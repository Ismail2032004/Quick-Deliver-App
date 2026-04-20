import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final androidNativeTrackingBridgeProvider =
    Provider<AndroidNativeTrackingBridge>((ref) {
      return const AndroidNativeTrackingBridge();
    });

class AndroidNativeTrackingBridge {
  const AndroidNativeTrackingBridge();

  static const _channel = MethodChannel('quickdeliver/android_tracking');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<AndroidNativeTrackingStatus> getStatus() async {
    if (!isSupported) {
      return const AndroidNativeTrackingStatus();
    }
    final raw = await _channel.invokeMapMethod<String, dynamic>('getStatus');
    return AndroidNativeTrackingStatus.fromMap(raw ?? const {});
  }

  Future<AndroidNativeTrackingStatus> getDiagnostics() async {
    if (!isSupported) {
      return const AndroidNativeTrackingStatus();
    }
    final raw = await _channel.invokeMapMethod<String, dynamic>('getDiagnostics');
    return AndroidNativeTrackingStatus.fromMap(raw ?? const {});
  }

  Future<AndroidNativeTrackingStatus> startTracking({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String accessToken,
    required String? refreshToken,
    required String riderId,
    required String riderName,
    required String orderId,
  }) async {
    if (!isSupported) {
      return const AndroidNativeTrackingStatus();
    }
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'startTracking',
      {
        'supabaseUrl': supabaseUrl,
        'supabaseAnonKey': supabaseAnonKey,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'riderId': riderId,
        'riderName': riderName,
        'orderId': orderId,
      },
    );
    return AndroidNativeTrackingStatus.fromMap(raw ?? const {});
  }

  Future<AndroidNativeTrackingStatus> stopTracking({
    required bool markInactive,
  }) async {
    if (!isSupported) {
      return const AndroidNativeTrackingStatus();
    }
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'stopTracking',
      {'markInactive': markInactive},
    );
    return AndroidNativeTrackingStatus.fromMap(raw ?? const {});
  }
}

class AndroidNativeTrackingStatus {
  const AndroidNativeTrackingStatus({
    this.isActive = false,
    this.isServiceRunning = false,
    this.orderId,
    this.lastError,
    this.statusMessage,
    this.fineLocationGranted = false,
    this.backgroundLocationGranted = false,
    this.notificationsGranted = false,
    this.gpsEnabled = false,
    this.batteryOptimizationActive = false,
  });

  factory AndroidNativeTrackingStatus.fromMap(Map<String, dynamic> map) {
    return AndroidNativeTrackingStatus(
      isActive: map['isActive'] == true,
      isServiceRunning: map['isServiceRunning'] == true,
      orderId: map['orderId'] as String?,
      lastError: map['lastError'] as String?,
      statusMessage: map['statusMessage'] as String?,
      fineLocationGranted: map['fineLocationGranted'] == true,
      backgroundLocationGranted: map['backgroundLocationGranted'] == true,
      notificationsGranted: map['notificationsGranted'] == true,
      gpsEnabled: map['gpsEnabled'] == true,
      batteryOptimizationActive: map['batteryOptimizationActive'] == true,
    );
  }

  final bool isActive;
  final bool isServiceRunning;
  final String? orderId;
  final String? lastError;
  final String? statusMessage;
  final bool fineLocationGranted;
  final bool backgroundLocationGranted;
  final bool notificationsGranted;
  final bool gpsEnabled;
  final bool batteryOptimizationActive;

  String? get riderGuidance {
    if (!gpsEnabled) {
      return 'Turn on GPS/location services before starting rider tracking.';
    }
    if (!fineLocationGranted) {
      return 'Allow location permission before starting rider tracking.';
    }
    if (!backgroundLocationGranted) {
      return 'For stronger Android background tracking, allow location access all the time in system settings.';
    }
    if (!notificationsGranted) {
      return 'Allow notifications so Android can keep the live-tracking notification visible.';
    }
    if (batteryOptimizationActive) {
      return 'Battery optimization is still active and may reduce background tracking reliability on some Android devices.';
    }
    return statusMessage;
  }
}
