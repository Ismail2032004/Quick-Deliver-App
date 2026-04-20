import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/operations/domain/models/app_notification.dart';
import '../../features/operations/presentation/controllers/delivery_hub_controller.dart';
import 'section_header.dart';
import 'state_widgets.dart';

Future<void> showNotificationCenterSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String subtitle,
  required List<AppNotification> notifications,
  required Future<void> Function(AppNotification notification) onOpenOrder,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      if (notifications.isEmpty) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: EmptyStateView(
              title: 'No notifications yet',
              message: 'Important order and delivery updates will appear here.',
              icon: Icons.notifications_none_rounded,
            ),
          ),
        );
      }

      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SectionHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 12),
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
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pop();
                      if (notification.orderId != null) {
                        await onOpenOrder(notification);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
