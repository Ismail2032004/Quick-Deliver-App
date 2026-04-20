import '../models/app_user.dart';
import '../models/app_role.dart';

abstract class UserRepository {
  Future<AppUser?> getCurrentUserProfile();
  Future<AppUser?> getUserById(String userId);
  Future<AppUser> upsertUser(AppUser user);
  Stream<AppUser?> watchUser(String userId);
  Stream<List<AppUser>> watchUsers({AppRole? role});
}
