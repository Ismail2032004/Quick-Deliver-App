import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/app_role.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/role_application.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/repositories/auth_repository.dart';
import '../../../../core/repositories/user_repository.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/supabase/services/supabase_storage_service.dart';
import '../../../customer/data/mock/mock_customer_seed_data.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
    storageService: AppConfig.isSupabaseConfigured
        ? ref.watch(storageServiceProvider)
        : null,
  );
});

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    required SupabaseStorageService? storageService,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       _storageService = storageService;

  static const _onboardingKey = 'quickdeliver.has_seen_onboarding';

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final SupabaseStorageService? _storageService;

  StreamSubscription<AppUser?>? _authSubscription;
  bool _isInitialized = false;
  bool _hasSeenOnboarding = false;
  bool _isBusy = false;
  String? _lastError;
  String? _lastInfoMessage;
  String? _pendingVerificationEmail;
  AppRole _pendingSignupRole = AppRole.customer;
  bool _shouldShowWorkspaceChooser = false;
  bool _isSigningOutIntentionally = false;
  AppUser? _currentUser;

  bool get isInitialized => _isInitialized;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isBusy => _isBusy;
  String? get lastError => _lastError;
  String? get lastInfoMessage => _lastInfoMessage;
  AppUser? get currentUser => _currentUser;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  AppRole get pendingSignupRole => _pendingSignupRole;
  bool get isAwaitingEmailVerification =>
      _pendingVerificationEmail != null && _currentUser == null;
  bool get shouldShowWorkspaceChooser => _shouldShowWorkspaceChooser;
  List<AppRole> get approvedRoles =>
      _currentUser?.approvedRoles ?? const [AppRole.customer];
  bool get canSwitchRoles => approvedRoles.length > 1;
  String get preferredDashboardRoute {
    return _currentUser == null ? AppRoutes.login : resolvedLandingRoute;
  }

  static String routeForRole(AppRole role) {
    return switch (role) {
      AppRole.customer => AppRoutes.customerDashboard,
      AppRole.rider => AppRoutes.riderDashboard,
      AppRole.owner => AppRoutes.ownerDashboard,
    };
  }

  AppRole get resolvedLandingRole {
    final user = _currentUser;
    if (user == null) {
      return AppRole.customer;
    }
    if (user.hasApprovedRole(user.role)) {
      return user.role;
    }
    return user.approvedRoles.isEmpty
        ? AppRole.customer
        : user.approvedRoles.first;
  }

  String get resolvedLandingRoute => routeForRole(resolvedLandingRole);

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _setBusy(true, notify: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenOnboarding = prefs.getBool(_onboardingKey) ?? false;
      if (AppConfig.demoMode) {
        _lastError = null;
        return;
      }
      await _authRepository.initialize();
      _currentUser = await _authRepository.refreshCurrentUser();
      if (_currentUser != null) {
        _clearPendingVerification(notify: false);
      }
      _authSubscription?.cancel();
      _authSubscription = _authRepository.authStateChanges().listen((user) {
        final previousUser = _currentUser;
        final isIntentionalSignOut = _isSigningOutIntentionally;
        if (_isInitialized &&
            user == null &&
            previousUser != null &&
            !isIntentionalSignOut) {
          _lastError = 'Your session expired. Please sign in again.';
        }
        _currentUser = user;
        if (user != null) {
          _clearPendingVerification(notify: false);
          _pendingSignupRole = AppRole.customer;
          _lastError = null;
          _lastInfoMessage = null;
          _isSigningOutIntentionally = false;
        } else {
          _shouldShowWorkspaceChooser = false;
          if (isIntentionalSignOut) {
            _lastError = null;
            _lastInfoMessage = null;
            _isSigningOutIntentionally = false;
          }
        }
        notifyListeners();
      });
      _lastError = null;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      _isInitialized = true;
      _setBusy(false);
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    _hasSeenOnboarding = true;
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _runBusyTask(() async {
      if (AppConfig.demoMode) {
        final normalizedEmail = email.trim().toLowerCase();
        AppUser? demoUser;
        for (final user in MockCustomerSeedData.users) {
          if (user.email.toLowerCase() == normalizedEmail) {
            demoUser = user;
            break;
          }
        }
        _currentUser =
            demoUser ??
            AppUser(
              id: 'user-demo',
              name: _extractNameFromEmail(email),
              email: email.trim(),
              role: AppRole.customer,
              phoneNumber: '+233200000000',
              approvedRoles: const [AppRole.customer],
            );
        _shouldShowWorkspaceChooser = true;
        return;
      }
      try {
        _currentUser = await _authRepository.signIn(
          email: email.trim(),
          password: password,
        );
        _clearPendingVerification(notify: false);
        _pendingSignupRole = AppRole.customer;
        _shouldShowWorkspaceChooser = _currentUser != null;
      } catch (error) {
        if (_isEmailConfirmationMessage(error.toString())) {
          _pendingVerificationEmail = email.trim();
          _lastInfoMessage =
              'Verify your account from the email we sent, then sign in again.';
        }
        rethrow;
      }
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required AppRole signupRole,
  }) async {
    await _runBusyTask(() async {
      _pendingSignupRole = signupRole;
      if (AppConfig.demoMode) {
        _currentUser = _buildSignedUpUser(
          id: 'user-${DateTime.now().millisecondsSinceEpoch}',
          name: name.trim(),
          email: email.trim(),
          signupRole: signupRole,
        );
        _lastInfoMessage = _signupInfoMessage(signupRole);
        _shouldShowWorkspaceChooser = true;
        return;
      }
      final registeredUser = await _authRepository.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
        signupRole: signupRole,
      );
      if (registeredUser != null) {
        _currentUser = registeredUser;
        _clearPendingVerification(notify: false);
        _lastInfoMessage = _signupInfoMessage(signupRole);
        _shouldShowWorkspaceChooser = true;
        return;
      }
      _currentUser = null;
      _pendingVerificationEmail = email.trim();
      _lastInfoMessage = _verificationPendingMessage(signupRole);
      _shouldShowWorkspaceChooser = false;
    });
  }

  Future<void> selectRole(AppRole role) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }
    if (!user.hasApprovedRole(role)) {
      throw StateError(
        'This account is not approved for the ${role.label.toLowerCase()} workspace yet.',
      );
    }
    await _runBusyTask(() async {
      if (AppConfig.demoMode) {
        _currentUser = user.copyWith(role: role);
        return;
      }
      _currentUser = await _userRepository.upsertUser(user.copyWith(role: role));
    });
  }

  Future<void> submitRoleApplication({
    required AppRole role,
    required Map<String, dynamic> formData,
  }) async {
    final user = _currentUser;
    if (user == null || role == AppRole.customer) {
      return;
    }
    await _runBusyTask(() async {
      final updated = switch (role) {
        AppRole.owner => user.copyWith(
            ownerApplicationStatus: RoleApplicationStatus.pending,
            ownerApplicationData: formData,
          ),
        AppRole.rider => user.copyWith(
            riderApplicationStatus: RoleApplicationStatus.pending,
            riderApplicationData: formData,
          ),
        AppRole.customer => user,
      };
      if (AppConfig.demoMode) {
        _currentUser = updated;
        return;
      }
      _currentUser = await _userRepository.upsertUser(updated);
    });
    _lastInfoMessage =
        'Your ${role.label.toLowerCase()} application has been submitted for review.';
    notifyListeners();
  }

  Future<void> updateProfile({
    required String fullName,
    required String phoneNumber,
    String? avatarUrl,
  }) async {
    final user = _currentUser;
    if (user == null) {
      return;
    }
    await _runBusyTask(() async {
      if (AppConfig.demoMode) {
        _currentUser = user.copyWith(
          name: fullName.trim(),
          phoneNumber: phoneNumber.trim().isEmpty ? null : phoneNumber.trim(),
          avatarUrl: avatarUrl ?? user.avatarUrl,
        );
        return;
      }
      String? resolvedAvatarUrl = avatarUrl ?? user.avatarUrl;
      final storageService = _storageService;
      if (resolvedAvatarUrl != null &&
          resolvedAvatarUrl.isNotEmpty &&
          !resolvedAvatarUrl.startsWith('http') &&
          storageService != null) {
        resolvedAvatarUrl = await storageService.uploadProfileAvatar(
          userId: user.id,
          imagePath: resolvedAvatarUrl,
        );
      }
      _currentUser = await _userRepository.upsertUser(
        user.copyWith(
          name: fullName.trim(),
          phoneNumber: phoneNumber.trim().isEmpty ? null : phoneNumber.trim(),
          avatarUrl: resolvedAvatarUrl,
        ),
      );
    });
  }

  Future<void> signOut() async {
    await _runBusyTask(() async {
      _isSigningOutIntentionally = true;
      _lastError = null;
      _lastInfoMessage = null;
      try {
        if (AppConfig.demoMode) {
          _currentUser = null;
          _clearPendingVerification(notify: false);
          _pendingSignupRole = AppRole.customer;
          _shouldShowWorkspaceChooser = false;
          return;
        }
        await _authRepository.signOut();
        _currentUser = null;
        _clearPendingVerification(notify: false);
        _pendingSignupRole = AppRole.customer;
        _shouldShowWorkspaceChooser = false;
      } finally {
        _isSigningOutIntentionally = false;
      }
    });
  }

  void markWorkspaceChooserSeen() {
    if (!_shouldShowWorkspaceChooser) {
      return;
    }
    _shouldShowWorkspaceChooser = false;
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _runBusyTask(() async {
      if (AppConfig.demoMode) {
        return;
      }
      await _authRepository.sendPasswordResetEmail(
        email: email.trim(),
        redirectTo: AppConfig.passwordResetRedirectUrl,
      );
    });
  }

  Future<void> resendVerificationEmail({String? email}) async {
    await _runBusyTask(() async {
      if (AppConfig.demoMode) {
        _lastInfoMessage =
            'Demo mode does not send verification emails automatically.';
        return;
      }
      final resolvedEmail = (email ?? _pendingVerificationEmail ?? '').trim();
      if (resolvedEmail.isEmpty) {
        throw StateError('Enter your email address to resend verification.');
      }
      await _authRepository.resendVerificationEmail(
        email: resolvedEmail,
        redirectTo: AppConfig.authCallbackUrl,
      );
      _pendingVerificationEmail = resolvedEmail;
      _lastInfoMessage =
          'Verification email sent. Open the link on this device after it arrives.';
    });
  }

  Future<void> updatePassword({required String password}) async {
    await _runBusyTask(() async {
      if (AppConfig.demoMode) {
        return;
      }
      await _authRepository.updatePassword(password: password);
    });
  }

  Future<void> _runBusyTask(Future<void> Function() action) async {
    _setBusy(true);
    try {
      _lastError = null;
      await action();
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value, {bool notify = true}) {
    _isBusy = value;
    if (notify) {
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

  void _clearPendingVerification({bool notify = true}) {
    _pendingVerificationEmail = null;
    final infoMessage = _lastInfoMessage;
    if (infoMessage != null &&
        (infoMessage.contains('verify your account') ||
            infoMessage.contains('Verification email sent'))) {
      _lastInfoMessage = null;
    }
    if (notify) {
      notifyListeners();
    }
  }

  bool _isEmailConfirmationMessage(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('confirm your email') ||
        normalized.contains('email not confirmed');
  }

  AppUser _buildSignedUpUser({
    required String id,
    required String name,
    required String email,
    required AppRole signupRole,
  }) {
    return AppUser(
      id: id,
      name: name,
      email: email,
      role: AppRole.customer,
      phoneNumber: '+233200000000',
      approvedRoles: const [AppRole.customer],
      ownerApplicationStatus: signupRole == AppRole.owner
          ? RoleApplicationStatus.pending
          : RoleApplicationStatus.notApplied,
      riderApplicationStatus: signupRole == AppRole.rider
          ? RoleApplicationStatus.pending
          : RoleApplicationStatus.notApplied,
      ownerApplicationData: signupRole == AppRole.owner
          ? {
              'source': 'signup',
              'requested_at': DateTime.now().toIso8601String(),
              'contact_name': name,
              'contact_email': email,
            }
          : const {},
      riderApplicationData: signupRole == AppRole.rider
          ? {
              'source': 'signup',
              'requested_at': DateTime.now().toIso8601String(),
              'contact_name': name,
              'contact_email': email,
            }
          : const {},
    );
  }

  String _signupInfoMessage(AppRole signupRole) {
    return switch (signupRole) {
      AppRole.customer => 'Your customer account is ready to use.',
      AppRole.rider =>
        'Your customer account is ready. Rider access has been submitted for review.',
      AppRole.owner =>
        'Your customer account is ready. Business access has been submitted for review.',
    };
  }

  String _verificationPendingMessage(AppRole signupRole) {
    return switch (signupRole) {
      AppRole.customer =>
        'Account created. Check your email to verify your account before signing in.',
      AppRole.rider =>
        'Account created. Verify your email before signing in. After confirmation, you can continue with customer access while your rider request stays pending review.',
      AppRole.owner =>
        'Account created. Verify your email before signing in. After confirmation, you can continue with customer access while your business request stays pending review.',
    };
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
