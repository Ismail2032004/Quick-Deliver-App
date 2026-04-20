import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_role.dart';
import '../../models/app_user.dart';
import '../../repositories/user_repository.dart';
import '../mappers/supabase_mappers.dart';
import '../supabase_tables.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppUser?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return getUserById(user.id);
  }

  @override
  Future<AppUser?> getUserById(String userId) async {
    final response = await _client
        .from(SupabaseTables.profiles)
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    return SupabaseMappers.appUserFromMap(response);
  }

  @override
  Future<AppUser> upsertUser(AppUser user) async {
    final response = await _client
        .from(SupabaseTables.profiles)
        .upsert(SupabaseMappers.appUserToMap(user))
        .select()
        .single();
    return SupabaseMappers.appUserFromMap(response);
  }

  @override
  Stream<AppUser?> watchUser(String userId) {
    return watchUsers().map((users) {
      for (final user in users) {
        if (user.id == userId) {
          return user;
        }
      }
      return null;
    });
  }

  @override
  Stream<List<AppUser>> watchUsers({AppRole? role}) {
    return _client
        .from(SupabaseTables.profiles)
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) {
          final users = rows
              .map(SupabaseMappers.appUserFromMap)
              .toList(growable: false);
          if (role == null) {
            return users;
          }
          return users
              .where((user) => user.role == role)
              .toList(growable: false);
        });
  }
}
