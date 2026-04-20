import 'package:flutter/material.dart';

import '../../core/utils/order_status_codec.dart';
import '../../features/customer/domain/models/delivery_order.dart';

class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({
    super.key,
    required this.currentStatus,
    this.vertical = true,
  });

  final OrderStatus currentStatus;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.pickedUp,
      OrderStatus.delivering,
      OrderStatus.deliveredPendingProofReview,
      OrderStatus.delivered,
    ];

    final currentIndex = statuses.indexOf(currentStatus);

    final children = <Widget>[];
    for (var index = 0; index < statuses.length; index++) {
      final status = statuses[index];
      final isDone = currentIndex >= index;
      children.add(
        _TimelineNode(
          label: status.label,
          isDone: isDone,
        ),
      );
    }

    return vertical
        ? Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: child,
                  ),
                )
                .toList(),
          )
        : Wrap(spacing: 10, runSpacing: 10, children: children);
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.label, required this.isDone});

  final String label;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final color = isDone ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color.withValues(alpha: isDone ? 0.18 : 0.5),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDone ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
