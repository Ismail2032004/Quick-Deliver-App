import '../models/app_role.dart';
import '../models/app_user.dart';

abstract class AuthRepository {
  String? get currentAuthUserId;
  AppUser? get currentUser;

  Future<void> initialize();
  Future<AppUser?> signIn({required String email, required String password});

  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
    required AppRole signupRole,
  });

  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  });
  Future<void> resendVerificationEmail({
    required String email,
    String? redirectTo,
  });
  Future<void> updatePassword({required String password});
  Future<AppUser?> refreshCurrentUser();
  Future<void> signOut();
  Stream<AppUser?> authStateChanges();
}
