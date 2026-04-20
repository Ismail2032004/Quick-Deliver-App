import '../../features/operations/domain/models/app_notification.dart';

abstract class NotificationRepository {
  Future<void> sendNotification(AppNotification notification);
  Stream<List<AppNotification>> watchNotifications(String userId);
  Future<void> markNotificationRead(String notificationId);
}
