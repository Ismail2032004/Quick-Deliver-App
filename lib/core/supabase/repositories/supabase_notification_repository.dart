import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/operations/domain/models/app_notification.dart';
import '../../repositories/notification_repository.dart';
import '../mappers/supabase_mappers.dart';
import '../supabase_tables.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> sendNotification(AppNotification notification) async {
    await _client
        .from(SupabaseTables.notifications)
        .insert(SupabaseMappers.notificationToMap(notification));
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _client
        .from(SupabaseTables.notifications)
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows
            .map(SupabaseMappers.notificationFromMap)
            .where((notification) => notification.userId == userId)
            .toList(growable: false));
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _client
        .from(SupabaseTables.notifications)
        .update({'is_read': true})
        .eq('id', notificationId);
  }
}
