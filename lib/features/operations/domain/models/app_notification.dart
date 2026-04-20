enum AppNotificationType {
  orderStatus,
  riderAssigned,
  proofUploaded,
  promotion,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.orderId,
    this.isRead = false,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final String? orderId;
  final bool isRead;

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    AppNotificationType? type,
    DateTime? createdAt,
    String? orderId,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      isRead: isRead ?? this.isRead,
    );
  }
}
