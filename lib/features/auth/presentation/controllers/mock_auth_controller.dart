import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_role.dart';
import '../../../../core/models/app_user.dart';

final mockAuthControllerProvider = ChangeNotifierProvider<MockAuthController>((
  ref,
) {
  return MockAuthController();
});

class MockAuthController extends ChangeNotifier {
  bool _isInitialized = false;
  bool _hasSeenOnboarding = false;
  bool _isBusy = false;
  AppUser? _currentUser;

  bool get isInitialized => _isInitialized;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isBusy => _isBusy;
  AppUser? get currentUser => _currentUser;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    _isInitialized = true;
    notifyListeners();
  }

  void completeOnboarding() {
    _hasSeenOnboarding = true;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _runBusyTask(() async {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _currentUser = AppUser(
        id: 'user-demo',
        name: _extractNameFromEmail(email),
        email: email.trim(),
        role: AppRole.customer,
        phoneNumber: '+233200000000',
      );
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required AppRole signupRole,
  }) async {
    await _runBusyTask(() async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _currentUser = AppUser(
        id: 'user-${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        email: email.trim(),
        role: AppRole.customer,
        phoneNumber: '+233200000000',
        approvedRoles: const [AppRole.customer],
      );
    });
  }

  void selectRole(AppRole role) {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = AppUser(
      id: switch (role) {
        AppRole.customer => 'demo-customer',
        AppRole.rider => 'demo-rider',
        AppRole.owner => 'demo-owner',
      },
      name: switch (role) {
        AppRole.customer => user.name.isEmpty ? 'Ama Boateng' : user.name,
        AppRole.rider => user.name.isEmpty ? 'Kojo Mensah' : user.name,
        AppRole.owner => user.name.isEmpty ? 'Efua Market' : user.name,
      },
      email: user.email,
      role: role,
      phoneNumber: switch (role) {
        AppRole.customer => '+233244100100',
        AppRole.rider => '+233244300300',
        AppRole.owner => '+233244200200',
      },
      avatarUrl: user.avatarUrl,
    );
    notifyListeners();
  }

  void signOut() {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> useDemoAccount(AppRole role) async {
    await _runBusyTask(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _currentUser = AppUser(
        id: 'demo-${role.name}',
        name: switch (role) {
          AppRole.customer => 'Ama Boateng',
          AppRole.rider => 'Kojo Mensah',
          AppRole.owner => 'Efua Market',
        },
        email: '${role.name}@quickdeliver.demo',
        role: role,
        phoneNumber: switch (role) {
          AppRole.customer => '+233244100100',
          AppRole.rider => '+233244300300',
          AppRole.owner => '+233244200200',
        },
      );
    });
  }

  Future<void> _runBusyTask(Future<void> Function() action) async {
    _isBusy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _extractNameFromEmail(String email) {
    final cleaned = email.trim().split('@').first.replaceAll('.', ' ');
    if (cleaned.isEmpty) {
      return 'QuickDeliver User';
    }

    return cleaned
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
