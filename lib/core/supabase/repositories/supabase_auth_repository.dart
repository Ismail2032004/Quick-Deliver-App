import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../models/app_role.dart';
import '../../models/app_user.dart';
import '../../models/role_application.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../utils/app_role_codec.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    required SupabaseClient client,
    required UserRepository userRepository,
  }) : _client = client,
       _userRepository = userRepository;

  final SupabaseClient _client;
  final UserRepository _userRepository;

  @override
  String? get currentAuthUserId => _client.auth.currentUser?.id;

  @override
  AppUser? get currentUser => _cachedUser;

  AppUser? _cachedUser;

  @override
  Future<void> initialize() async {
    _cachedUser = await refreshCurrentUser();
  }

  @override
  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw StateError(_mapAuthException(error));
    }
    _cachedUser = await refreshCurrentUser();
    return _cachedUser;
  }

  @override
  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
    required AppRole signupRole,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AppConfig.authCallbackUrl,
        data: {
          'full_name': name,
          'signup_role': signupRole.storageValue,
        },
      );
      if (response.session == null && response.user != null) {
        _cachedUser = null;
        return null;
      }
      _cachedUser = await refreshCurrentUser();
      return _cachedUser;
    } on AuthException catch (error) {
      throw StateError(_mapAuthException(error));
    }
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  @override
  Future<void> resendVerificationEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: redirectTo,
      );
    } on AuthException catch (error) {
      throw StateError(_mapAuthException(error));
    }
  }

  @override
  Future<void> updatePassword({required String password}) async {
    await _client.auth.updateUser(UserAttributes(password: password));
    _cachedUser = await refreshCurrentUser();
  }

  @override
  Future<AppUser?> refreshCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      _cachedUser = null;
      return null;
    }
    _cachedUser = await _userRepository.getUserById(authUser.id);
    if (_cachedUser == null) {
      final metadata = authUser.userMetadata ?? const <String, dynamic>{};
      _cachedUser = await _userRepository.upsertUser(
        _seedUserFromAuth(
          authUser,
          fallbackName:
              (metadata['full_name'] as String?)?.trim().isNotEmpty == true
              ? metadata['full_name'] as String
              : (authUser.email?.split('@').first ?? 'QuickDeliver User'),
        ),
      );
    }
    return _cachedUser;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _cachedUser = null;
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final authUser = event.session?.user ?? _client.auth.currentUser;
      if (authUser == null) {
        _cachedUser = null;
        return null;
      }
      _cachedUser = await refreshCurrentUser();
      return _cachedUser;
    });
  }

  String _mapAuthException(AuthException error) {
    final message = error.message.trim();
    final normalized = message.toLowerCase();

    if (normalized.contains('email not confirmed') ||
        normalized.contains('email not confirmed yet') ||
        normalized.contains('email address not authorized')) {
      return 'Confirm your email before signing in. Check your inbox for the verification link.';
    }

    return message.isEmpty ? error.toString() : message;
  }

  AppUser _seedUserFromAuth(User authUser, {required String fallbackName}) {
    final metadata = authUser.userMetadata ?? const <String, dynamic>{};
    final signupRole = appRoleFromStorage(metadata['signup_role'] as String?);
    final now = DateTime.now().toIso8601String();

    return AppUser(
      id: authUser.id,
      name: fallbackName,
      email: authUser.email ?? '',
      role: AppRole.customer,
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
              'requested_at': now,
              'contact_name': fallbackName,
              'contact_email': authUser.email ?? '',
            }
          : const {},
      riderApplicationData: signupRole == AppRole.rider
          ? {
              'source': 'signup',
              'requested_at': now,
              'contact_name': fallbackName,
              'contact_email': authUser.email ?? '',
            }
          : const {},
    );
  }
}
