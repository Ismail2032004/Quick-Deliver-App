import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

final accountPreferencesProvider = StateNotifierProvider.family<
    AccountPreferencesController,
    AccountPreferencesState,
    String>((ref, userId) {
  return AccountPreferencesController(userId: userId)..initialize();
});

final currentAccountPreferencesProvider =
    Provider<AccountPreferencesState>((ref) {
      final user = ref.watch(authControllerProvider).currentUser;
      if (user == null) {
        return const AccountPreferencesState();
      }
      return ref.watch(accountPreferencesProvider(user.id));
    });

class SavedAddress {
  const SavedAddress({
    required this.label,
    required this.address,
  });

  final String label;
  final String address;

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'address': address,
    };
  }

  static SavedAddress fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      label: json['label'] as String? ?? 'Saved address',
      address: json['address'] as String? ?? '',
    );
  }
}

class PaymentMethodSnapshot {
  const PaymentMethodSnapshot({
    required this.label,
    required this.details,
    required this.isDefault,
  });

  final String label;
  final String details;
  final bool isDefault;

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'details': details,
      'is_default': isDefault,
    };
  }

  static PaymentMethodSnapshot fromJson(Map<String, dynamic> json) {
    return PaymentMethodSnapshot(
      label: json['label'] as String? ?? 'Card',
      details: json['details'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}

class AccountPreferencesState {
  const AccountPreferencesState({
    this.isLoaded = false,
    this.savedAddresses = const [],
    this.paymentMethods = const [],
  });

  final bool isLoaded;
  final List<SavedAddress> savedAddresses;
  final List<PaymentMethodSnapshot> paymentMethods;

  AccountPreferencesState copyWith({
    bool? isLoaded,
    List<SavedAddress>? savedAddresses,
    List<PaymentMethodSnapshot>? paymentMethods,
  }) {
    return AccountPreferencesState(
      isLoaded: isLoaded ?? this.isLoaded,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      paymentMethods: paymentMethods ?? this.paymentMethods,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'saved_addresses': savedAddresses.map((item) => item.toJson()).toList(),
      'payment_methods': paymentMethods.map((item) => item.toJson()).toList(),
    };
  }

  static AccountPreferencesState fromJson(Map<String, dynamic> json) {
    return AccountPreferencesState(
      isLoaded: true,
      savedAddresses: ((json['saved_addresses'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SavedAddress.fromJson)
          .toList(growable: false),
      paymentMethods: ((json['payment_methods'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PaymentMethodSnapshot.fromJson)
          .toList(growable: false),
    );
  }
}

class AccountPreferencesController
    extends StateNotifier<AccountPreferencesState> {
  AccountPreferencesController({required String userId})
    : _userId = userId,
      super(const AccountPreferencesState());

  final String _userId;
  SharedPreferences? _prefs;

  String get _storageKey => 'quickdeliver.account_preferences.$_userId';

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      state = const AccountPreferencesState(
        isLoaded: true,
        savedAddresses: [
          SavedAddress(label: 'Home', address: 'East Legon, Accra'),
        ],
        paymentMethods: [
          PaymentMethodSnapshot(
            label: 'Mobile money',
            details: 'Default wallet ending in 0100',
            isDefault: true,
          ),
        ],
      );
      await _persist();
      return;
    }
    try {
      state = AccountPreferencesState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      state = const AccountPreferencesState(isLoaded: true);
    }
  }

  Future<void> addSavedAddress(SavedAddress address) async {
    state = state.copyWith(
      isLoaded: true,
      savedAddresses: [...state.savedAddresses, address],
    );
    await _persist();
  }

  Future<void> removeSavedAddress(SavedAddress address) async {
    state = state.copyWith(
      isLoaded: true,
      savedAddresses: state.savedAddresses
          .where((item) => item != address)
          .toList(growable: false),
    );
    await _persist();
  }

  Future<void> addPaymentMethod(PaymentMethodSnapshot method) async {
    final existing = state.paymentMethods;
    final methods = existing
        .map(
          (item) => item.isDefault && method.isDefault
              ? PaymentMethodSnapshot(
                  label: item.label,
                  details: item.details,
                  isDefault: false,
                )
              : item,
        )
        .toList(growable: true)
      ..add(method);
    state = state.copyWith(isLoaded: true, paymentMethods: methods);
    await _persist();
  }

  Future<void> removePaymentMethod(PaymentMethodSnapshot method) async {
    state = state.copyWith(
      isLoaded: true,
      paymentMethods: state.paymentMethods
          .where((item) => item != method)
          .toList(growable: false),
    );
    await _persist();
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_storageKey, jsonEncode(state.toJson()));
  }
}
