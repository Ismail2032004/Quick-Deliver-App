import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../../domain/models/app_notification.dart';
import '../controllers/delivery_hub_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.notifications,
    this.onOpenOrder,
  });

  final String title;
  final String subtitle;
  final List<AppNotification> notifications;
  final Future<void> Function(BuildContext context, AppNotification notification)?
      onOpenOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      child: ListView(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionHeader(title: title, subtitle: subtitle),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (notifications.isEmpty)
            const EmptyStateView(
              title: 'No notifications yet',
              message: 'Important delivery and account updates will appear here.',
              icon: Icons.notifications_none_rounded,
            )
          else
            ...notifications.map(
              (notification) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: notification.isRead
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFFFF7ED),
                      child: Icon(
                        notification.isRead
                            ? Icons.notifications_none_rounded
                            : Icons.notifications_active_outlined,
                        color: notification.isRead
                            ? const Color(0xFF64748B)
                            : const Color(0xFFC2410C),
                      ),
                    ),
                    title: Text(notification.title),
                    subtitle: Text(notification.body),
                    trailing: notification.orderId == null
                        ? null
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      if (!notification.isRead) {
                        await ref
                            .read(deliveryHubProvider.notifier)
                            .markNotificationRead(notification.id);
                      }
                      if (!context.mounted || onOpenOrder == null) {
                        return;
                      }
                      await onOpenOrder!(context, notification);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
