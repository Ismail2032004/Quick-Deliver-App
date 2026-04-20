import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>((ref) {
      return AppSettingsController()..initialize();
    });

class AppSettingsState {
  const AppSettingsState({
    this.isLoaded = false,
    this.pushNotificationsEnabled = true,
    this.darkModeEnabled = false,
    this.largerTextEnabled = false,
    this.reducedMotionEnabled = false,
    this.highContrastEnabled = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.languageCode = 'en',
    this.locationSharingDescription =
        'QuickDeliver uses location during active deliveries and checkout helpers only.',
  });

  final bool isLoaded;
  final bool pushNotificationsEnabled;
  final bool darkModeEnabled;
  final bool largerTextEnabled;
  final bool reducedMotionEnabled;
  final bool highContrastEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String languageCode;
  final String locationSharingDescription;

  double get textScaleFactor => largerTextEnabled ? 1.12 : 1;

  ThemeMode get themeMode =>
      darkModeEnabled ? ThemeMode.dark : ThemeMode.light;

  AppSettingsState copyWith({
    bool? isLoaded,
    bool? pushNotificationsEnabled,
    bool? darkModeEnabled,
    bool? largerTextEnabled,
    bool? reducedMotionEnabled,
    bool? highContrastEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? languageCode,
    String? locationSharingDescription,
  }) {
    return AppSettingsState(
      isLoaded: isLoaded ?? this.isLoaded,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      largerTextEnabled: largerTextEnabled ?? this.largerTextEnabled,
      reducedMotionEnabled:
          reducedMotionEnabled ?? this.reducedMotionEnabled,
      highContrastEnabled: highContrastEnabled ?? this.highContrastEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      languageCode: languageCode ?? this.languageCode,
      locationSharingDescription:
          locationSharingDescription ?? this.locationSharingDescription,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_notifications_enabled': pushNotificationsEnabled,
      'dark_mode_enabled': darkModeEnabled,
      'larger_text_enabled': largerTextEnabled,
      'reduced_motion_enabled': reducedMotionEnabled,
      'high_contrast_enabled': highContrastEnabled,
      'sound_enabled': soundEnabled,
      'vibration_enabled': vibrationEnabled,
      'language_code': languageCode,
      'location_sharing_description': locationSharingDescription,
    };
  }

  static AppSettingsState fromJson(Map<String, dynamic> json) {
    return AppSettingsState(
      isLoaded: true,
      pushNotificationsEnabled:
          json['push_notifications_enabled'] as bool? ?? true,
      darkModeEnabled: json['dark_mode_enabled'] as bool? ?? false,
      largerTextEnabled: json['larger_text_enabled'] as bool? ?? false,
      reducedMotionEnabled:
          json['reduced_motion_enabled'] as bool? ?? false,
      highContrastEnabled: json['high_contrast_enabled'] as bool? ?? false,
      soundEnabled: json['sound_enabled'] as bool? ?? true,
      vibrationEnabled: json['vibration_enabled'] as bool? ?? true,
      languageCode: json['language_code'] as String? ?? 'en',
      locationSharingDescription:
          json['location_sharing_description'] as String? ??
          'QuickDeliver uses location during active deliveries and checkout helpers only.',
    );
  }
}

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController() : super(const AppSettingsState());

  static const _storageKey = 'quickdeliver.app_settings.v1';
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      state = state.copyWith(isLoaded: true);
      return;
    }
    try {
      state = AppSettingsState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> update({
    bool? pushNotificationsEnabled,
    bool? darkModeEnabled,
    bool? largerTextEnabled,
    bool? reducedMotionEnabled,
    bool? highContrastEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? languageCode,
    String? locationSharingDescription,
  }) async {
    final next = state.copyWith(
      isLoaded: true,
      pushNotificationsEnabled: pushNotificationsEnabled,
      darkModeEnabled: darkModeEnabled,
      largerTextEnabled: largerTextEnabled,
      reducedMotionEnabled: reducedMotionEnabled,
      highContrastEnabled: highContrastEnabled,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
      languageCode: languageCode,
      locationSharingDescription: locationSharingDescription,
    );
    state = next;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_storageKey, jsonEncode(next.toJson()));
  }
}
