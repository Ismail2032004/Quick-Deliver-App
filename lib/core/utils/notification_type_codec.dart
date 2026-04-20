import '../../features/operations/domain/models/app_notification.dart';

extension AppNotificationTypeCodec on AppNotificationType {
  String get storageValue => switch (this) {
    AppNotificationType.orderStatus => 'order_status',
    AppNotificationType.riderAssigned => 'rider_assigned',
    AppNotificationType.proofUploaded => 'proof_uploaded',
    AppNotificationType.promotion => 'promotion',
  };
}

AppNotificationType notificationTypeFromStorage(String? value) {
  return switch (value) {
    'order_status' => AppNotificationType.orderStatus,
    'rider_assigned' => AppNotificationType.riderAssigned,
    'proof_uploaded' => AppNotificationType.proofUploaded,
    'promotion' => AppNotificationType.promotion,
    _ => AppNotificationType.orderStatus,
  };
}
