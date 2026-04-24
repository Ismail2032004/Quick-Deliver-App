import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickdeliver/core/config/app_config.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/models/role_application.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/phone_service.dart';
import '../../../../core/utils/delivery_user_messages.dart';
import '../../../../core/utils/order_status_codec.dart';
import '../../../../features/account/presentation/controllers/account_preferences_controller.dart';
import '../../../../features/settings/presentation/controllers/app_settings_controller.dart';
import '../../../../shared/widgets/contact_action_bar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_widgets.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../customer/domain/models/business.dart';
import '../../../customer/domain/models/delivery_order.dart';
import '../../../customer/domain/models/product.dart';
import '../../../dashboard/presentation/controllers/dashboard_tab_controller.dart';
import '../../../operations/domain/models/app_notification.dart';
import '../../../operations/domain/models/rider_location.dart';
import '../../../operations/presentation/controllers/delivery_hub_controller.dart';

class OwnerOverviewTab extends ConsumerWidget {
  const OwnerOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deliveryHubProvider);
    final owner = ref.watch(authControllerProvider).currentUser;
    final ownedBusinesses = owner == null
        ? const <Business>[]
        : state.businesses
              .where((business) => business.ownerId == owner.id)
              .toList(growable: false);
    final ownedBusinessIds = ownedBusinesses.map((business) => business.id).toSet();
    final ownedProducts = state.products
        .where((product) => ownedBusinessIds.contains(product.businessId))
        .toList(growable: false);
    final openOrders = state.orders
        .where(
          (order) =>
              order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled,
        )
        .where((order) => ownedBusinessIds.contains(order.businessId))
        .length;
    final notifications = owner == null
        ? const <AppNotification>[]
        : state.notifications
              .where((notification) => notification.userId == owner.id)
              .toList(growable: false);
    final unreadNotifications = notifications.where((item) => !item.isRead).length;

    return ListView(
      children: [
        _HeroOwnerCard(
          title: 'Keep every storefront moving',
          body:
              'Manage business profile, products, incoming orders, and rider assignment from one startup-style workspace.',
        ),
        const SizedBox(height: 18),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.12,
          children: [
            _MetricCard(
              label: 'Businesses',
              value: '${ownedBusinesses.length}',
              color: const Color(0xFF0F766E),
              icon: Icons.storefront_rounded,
              onTap: () {
                ref.read(dashboardTabProvider('owner-dashboard').notifier).state =
                    2;
              },
            ),
            _MetricCard(
              label: 'Products',
              value: '${ownedProducts.length}',
              color: const Color(0xFF2563EB),
              icon: Icons.inventory_2_outlined,
              onTap: () {
                ref.read(dashboardTabProvider('owner-dashboard').notifier).state =
                    2;
              },
            ),
            _MetricCard(
              label: 'Open orders',
              value: '$openOrders',
              color: const Color(0xFFF97316),
              icon: Icons.receipt_long_rounded,
              onTap: () {
                ref.read(dashboardTabProvider('owner-dashboard').notifier).state =
                    1;
              },
            ),
            _MetricCard(
              label: 'Notifications',
              value: '$unreadNotifications',
              color: const Color(0xFF7C3AED),
              icon: Icons.notifications_outlined,
              onTap: () {
                if (notifications.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No new notifications for your business yet.'),
                    ),
                  );
                  return;
                }
                context.push(AppRoutes.ownerNotifications);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class OwnerOrdersTab extends ConsumerWidget {
  const OwnerOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(deliveryHubProvider);
    final owner = ref.watch(authControllerProvider).currentUser;
    final ownedBusinesses = owner == null
        ? const <Business>[]
        : hub.businesses
              .where((business) => business.ownerId == owner.id)
              .toList(growable: false);
    final ownedBusinessIds = ownedBusinesses.map((business) => business.id).toSet();
    final riders = ref
        .read(deliveryHubProvider.notifier)
        .usersByRole(AppRole.rider);
    final riderLocations = hub.riderLocations;
    final ownerOrders = hub.orders
        .where((order) => ownedBusinessIds.contains(order.businessId))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (ownedBusinesses.isEmpty) {
      return const EmptyStateView(
        title: 'No business profile linked',
        message:
            'Connect or create a business profile for this owner account to see incoming orders here.',
        icon: Icons.storefront_rounded,
      );
    }

    if (ownerOrders.isEmpty) {
      return EmptyStateView(
        title: 'No incoming orders yet',
        message:
            'New customer orders for ${ownedBusinesses.first.name} will appear here with status controls and rider assignment.',
        actionLabel: 'Manage products',
        onAction: () {
          ref.read(dashboardTabProvider('owner-dashboard').notifier).state = 2;
        },
        icon: Icons.receipt_long_rounded,
      );
    }

    return ListView(
      children: [
        SectionHeader(
          title: 'Incoming orders',
          subtitle:
              ownedBusinesses.length == 1
                  ? 'Live orders for ${ownedBusinesses.first.name}.'
                  : 'Review, update status, and assign a rider for your active storefronts.',
        ),
        const SizedBox(height: 16),
        ...ownerOrders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${order.id} - ${order.businessName}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _OrderStatusBadge(
                          label: order.status.label,
                          color: _statusAccentFor(order.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(order.customerName),
                    const SizedBox(height: 4),
                    Text(
                      order.items
                          .map((item) => '${item.quantity}x ${item.productName}')
                          .join(', '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(order.deliveryAddress),
                    if (order.status == OrderStatus.deliveredPendingProofReview)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _RiderAssignmentBanner(
                          title: 'Proof review needed',
                          subtitle:
                              'The rider uploaded delivery proof. Confirm the final delivery once the proof looks correct.',
                          status: 'Awaiting review',
                        ),
                      ),
                    if (order.riderName != null) ...[
                      const SizedBox(height: 10),
                      _RiderAssignmentBanner(
                        title: 'Assigned rider',
                        subtitle:
                            '${order.riderName} is currently attached to this order and will see this delivery from the rider workspace.',
                        status: order.deliveryStatus?.label ??
                            _riderAvailabilityFor(
                              riderId: order.riderId,
                              orders: hub.orders,
                              riderLocations: riderLocations,
                            ).label,
                      ),
                    ],
                    if (order.riderName == null && order.status == OrderStatus.ready)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: _RiderAssignmentBanner(
                          title: 'Waiting for rider assignment',
                          subtitle:
                              'This order is ready. Assign a rider to move it into the delivery workflow.',
                          status: 'Unassigned',
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      _ownerOrderGuidance(order),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ContactActionBar(
                      onCallCustomer: order.customerPhone.trim().isEmpty
                          ? null
                          : () async {
                              final result = await ref
                                  .read(phoneServiceProvider)
                                  .tryCallNumber(order.customerPhone);
                              if (!context.mounted || result.success) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                            },
                      onCallRider: order.riderPhone == null
                          ? null
                          : () async {
                              final result = await ref
                                  .read(phoneServiceProvider)
                                  .tryCallNumber(order.riderPhone);
                              if (!context.mounted || result.success) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.message)),
                              );
                            },
                    ),
                    if (order.deliveryProofImageUrl != null) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SafeNetworkImage(
                          imageUrl: order.deliveryProofImageUrl!,
                          height: 160,
                          width: double.infinity,
                          placeholderIcon: Icons.verified_outlined,
                          placeholderLabel: 'Delivery proof',
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _OwnerOrderActionBar(order: order),
                    const SizedBox(height: 14),
                    if (_canOwnerManageRider(order))
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => _showRiderAssignmentSheet(
                                context,
                                ref,
                                order: order,
                                riders: riders,
                                orders: hub.orders,
                                riderLocations: riderLocations,
                              ),
                              icon: const Icon(Icons.person_search_rounded),
                              label: Text(
                                order.riderName == null
                                    ? 'Assign rider'
                                    : 'Reassign rider',
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerOrderActionBar extends ConsumerWidget {
  const _OwnerOrderActionBar({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _ownerActionsFor(order);
    if (actions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _ownerActionSummary(order),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF475569),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next actions',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in actions)
              action.isPrimary
                  ? FilledButton.tonalIcon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(deliveryHubProvider.notifier)
                              .updateOrderStatus(order.id, action.nextStatus);
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(action.successMessage)),
                          );
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                deliveryUserMessage(
                                  error,
                                  fallback:
                                      'We couldn\'t update the order status. Please try again.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(action.icon),
                      label: Text(action.label),
                    )
                  : OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(deliveryHubProvider.notifier)
                              .updateOrderStatus(order.id, action.nextStatus);
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(action.successMessage)),
                          );
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                deliveryUserMessage(
                                  error,
                                  fallback:
                                      'We couldn\'t update the order status. Please try again.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      icon: Icon(action.icon),
                      label: Text(action.label),
                    ),
          ],
        ),
      ],
    );
  }
}

class _OwnerOrderAction {
  const _OwnerOrderAction({
    required this.label,
    required this.nextStatus,
    required this.successMessage,
    required this.icon,
    this.isPrimary = true,
  });

  final String label;
  final OrderStatus nextStatus;
  final String successMessage;
  final IconData icon;
  final bool isPrimary;
}

List<_OwnerOrderAction> _ownerActionsFor(DeliveryOrder order) {
  return switch (order.status) {
    OrderStatus.pending => [
      _OwnerOrderAction(
        label: 'Confirm order',
        nextStatus: OrderStatus.confirmed,
        successMessage: '${order.id} is now confirmed.',
        icon: Icons.check_circle_outline_rounded,
      ),
      _OwnerOrderAction(
        label: 'Cancel order',
        nextStatus: OrderStatus.cancelled,
        successMessage: '${order.id} was cancelled.',
        icon: Icons.cancel_outlined,
        isPrimary: false,
      ),
    ],
    OrderStatus.confirmed => [
      _OwnerOrderAction(
        label: 'Start preparing',
        nextStatus: OrderStatus.preparing,
        successMessage: '${order.id} is now in preparation.',
        icon: Icons.restaurant_outlined,
      ),
      _OwnerOrderAction(
        label: 'Cancel order',
        nextStatus: OrderStatus.cancelled,
        successMessage: '${order.id} was cancelled.',
        icon: Icons.cancel_outlined,
        isPrimary: false,
      ),
    ],
    OrderStatus.preparing => [
      _OwnerOrderAction(
        label: 'Mark ready',
        nextStatus: OrderStatus.ready,
        successMessage: '${order.id} is ready for rider assignment.',
        icon: Icons.inventory_2_outlined,
      ),
      _OwnerOrderAction(
        label: 'Cancel order',
        nextStatus: OrderStatus.cancelled,
        successMessage: '${order.id} was cancelled.',
        icon: Icons.cancel_outlined,
        isPrimary: false,
      ),
    ],
    OrderStatus.deliveredPendingProofReview => [
      _OwnerOrderAction(
        label: 'Confirm delivery',
        nextStatus: OrderStatus.delivered,
        successMessage: '${order.id} was marked delivered.',
        icon: Icons.verified_outlined,
      ),
    ],
    _ => const [],
  };
}

bool _canOwnerManageRider(DeliveryOrder order) {
  return order.status == OrderStatus.ready ||
      order.status == OrderStatus.pickedUp ||
      order.status == OrderStatus.delivering;
}

String _ownerOrderGuidance(DeliveryOrder order) {
  return switch (order.status) {
    OrderStatus.pending =>
      'Waiting for business confirmation before kitchen or store prep begins.',
    OrderStatus.confirmed =>
      'The order is confirmed. Start preparing when the team begins fulfillment.',
    OrderStatus.preparing =>
      'Preparation is underway. Mark the order ready once it can be handed to a rider.',
    OrderStatus.ready => order.riderName == null
        ? 'The order is ready to leave the business. Assign a rider to hand it off.'
        : '${order.riderName} is assigned and can collect this ready order.',
    OrderStatus.pickedUp =>
      'The rider has collected the order. Delivery is now in progress.',
    OrderStatus.delivering =>
      'The rider is on the way to the customer. Waiting for delivery proof.',
    OrderStatus.deliveredPendingProofReview =>
      'Delivery proof is available. Review the proof and confirm the final delivery.',
    OrderStatus.delivered =>
      'This order is complete and confirmed delivered.',
    OrderStatus.cancelled =>
      'This order has been cancelled and no further owner action is required.',
  };
}

String _ownerActionSummary(DeliveryOrder order) {
  return switch (order.status) {
    OrderStatus.ready => 'Use rider assignment to send this order out for delivery.',
    OrderStatus.pickedUp =>
      'No business-side status action is needed right now. The rider is handling the handoff.',
    OrderStatus.delivering =>
      'No business-side status action is needed right now. Wait for delivery proof from the rider.',
    OrderStatus.delivered =>
      'No further business action is needed for this completed order.',
    OrderStatus.cancelled =>
      'No further business action is needed for this cancelled order.',
    _ => 'No additional actions are available right now.',
  };
}

Color _statusAccentFor(OrderStatus status) {
  return switch (status) {
    OrderStatus.pending => const Color(0xFFF59E0B),
    OrderStatus.confirmed => const Color(0xFF2563EB),
    OrderStatus.preparing => const Color(0xFFF97316),
    OrderStatus.ready => const Color(0xFF15803D),
    OrderStatus.pickedUp => const Color(0xFF0F766E),
    OrderStatus.delivering => const Color(0xFF7C3AED),
    OrderStatus.deliveredPendingProofReview => const Color(0xFF9333EA),
    OrderStatus.delivered => const Color(0xFF16A34A),
    OrderStatus.cancelled => const Color(0xFFB91C1C),
  };
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _RiderAvailability { available, busy, standby, offline }

extension _RiderAvailabilityX on _RiderAvailability {
  String get label {
    return switch (this) {
      _RiderAvailability.available => 'Available',
      _RiderAvailability.busy => 'Busy',
      _RiderAvailability.standby => 'Standby',
      _RiderAvailability.offline => 'Offline',
    };
  }

  Color get color {
    return switch (this) {
      _RiderAvailability.available => const Color(0xFF15803D),
      _RiderAvailability.busy => const Color(0xFFC2410C),
      _RiderAvailability.standby => const Color(0xFF2563EB),
      _RiderAvailability.offline => const Color(0xFF64748B),
    };
  }

  String descriptionFor(String firstName) {
    return switch (this) {
      _RiderAvailability.available =>
        '$firstName is online and ready for a new assignment.',
      _RiderAvailability.busy =>
        '$firstName already has an active delivery but can still be reassigned if needed.',
      _RiderAvailability.standby =>
        '$firstName is not sharing an active location right now, but assignment is still available in this testing build so you can switch accounts and continue later.',
      _RiderAvailability.offline =>
        '$firstName is not sharing a live location right now, but you can still assign the delivery and the rider can continue when they come online.',
    };
  }

  String get actionLabel {
    return switch (this) {
      _RiderAvailability.available => 'Assign',
      _RiderAvailability.busy => 'Reassign',
      _RiderAvailability.standby => 'Assign',
      _RiderAvailability.offline => 'Assign',
    };
  }

  bool get canAssign {
    return true;
  }
}

bool get _supportsSingleDeviceAssignmentTesting =>
    kDebugMode || AppConfig.demoMode;

_RiderAvailability _riderAvailabilityFor({
  required String? riderId,
  required List<DeliveryOrder> orders,
  required List<RiderLocation> riderLocations,
}) {
  if (riderId == null) {
    return _RiderAvailability.offline;
  }

  final hasOpenAssignment = orders.any(
    (order) =>
        order.riderId == riderId &&
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled,
  );
  final hasActiveLocation = riderLocations.any(
    (location) => location.riderId == riderId && location.isActive,
  );

  if (hasActiveLocation) {
    return hasOpenAssignment
        ? _RiderAvailability.busy
        : _RiderAvailability.available;
  }

  if (hasOpenAssignment) {
    return _RiderAvailability.busy;
  }

  if (_supportsSingleDeviceAssignmentTesting) {
    return _RiderAvailability.standby;
  }

  return _RiderAvailability.standby;
}

Future<void> _showRiderAssignmentSheet(
  BuildContext context,
  WidgetRef ref, {
  required DeliveryOrder order,
  required List<AppUser> riders,
  required List<DeliveryOrder> orders,
  required List<RiderLocation> riderLocations,
}) async {
  final parentContext = context;
  await showModalBottomSheet<void>(
    context: parentContext,
    showDragHandle: true,
    builder: (sheetContext) {
      final roster = [
        for (final rider in riders)
          (
            rider: rider,
            availability: _riderAvailabilityFor(
              riderId: rider.id,
              orders: orders,
              riderLocations: riderLocations,
            ),
          ),
      ];
      final hasStandbyRiders = roster.any(
        (entry) => entry.availability == _RiderAvailability.standby,
      );
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SectionHeader(
              title: 'Assign rider',
              subtitle:
                  'Choose from the rider roster and review each rider status before assignment.',
            ),
            const SizedBox(height: 12),
            if (hasStandbyRiders) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Single-device testing is active in this build. Riders without a live location can still be assigned here and will see the delivery the next time they sign in.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...roster.map((entry) {
              final rider = entry.rider;
              final availability = entry.availability;
              final selected = order.riderId == rider.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: availability.color.withValues(alpha: 0.14),
                      child: Icon(
                        Icons.two_wheeler_rounded,
                        color: availability.color,
                      ),
                    ),
                    title: Text(rider.name),
                    subtitle: Text(
                      availability.descriptionFor(rider.name.split(' ').first),
                    ),
                    trailing: selected
                        ? Chip(label: Text(availability.label))
                        : FilledButton.tonal(
                            onPressed: !availability.canAssign
                                ? null
                                : () async {
                                    try {
                                      await ref
                                          .read(deliveryHubProvider.notifier)
                                          .assignRider(order.id, rider);
                                      if (!parentContext.mounted) {
                                        return;
                                      }
                                      Navigator.of(sheetContext).pop();
                                      ScaffoldMessenger.of(parentContext)
                                        ..clearSnackBars()
                                        ..showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${rider.name} assigned to ${order.id}.',
                                          ),
                                        ),
                                      );
                                    } catch (error) {
                                      if (!parentContext.mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(parentContext)
                                        ..clearSnackBars()
                                        ..showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            deliveryUserMessage(
                                              error,
                                              fallback:
                                                  'We couldn\'t assign this rider. Please try again.',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: Text(availability.actionLabel),
                          ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

class _RiderAssignmentBanner extends StatelessWidget {
  const _RiderAssignmentBanner({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title • $status',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class OwnerManageTab extends ConsumerWidget {
  const OwnerManageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(deliveryHubProvider);
    final owner = ref.watch(authControllerProvider).currentUser;
    final ownedBusinesses = owner == null
        ? const <Business>[]
        : hub.businesses
              .where((business) => business.ownerId == owner.id)
              .toList(growable: false);
    final hasLoadableDemoTemplates =
        owner != null &&
        hub.businesses.any(
          (business) =>
              business.ownerId != owner.id &&
              (business.name == 'Campus Bites' ||
                  business.name == 'City Pharmacy'),
        ) &&
        _supportsSingleDeviceAssignmentTesting;
    final canLoadDemoStorefronts =
        owner != null &&
        ownedBusinesses.isEmpty &&
        hasLoadableDemoTemplates;

    if (ownedBusinesses.isEmpty) {
      return EmptyStateView(
        title: canLoadDemoStorefronts
            ? 'Load demo storefronts'
            : 'Create your storefront',
        message:
            canLoadDemoStorefronts
            ? 'This account does not own the seeded storefront rows yet. Load demo copies of Campus Bites and City Pharmacy into your owner account so you can demonstrate create, update, and delete actions.'
            : 'Set up your business profile so customers can discover your store and place real orders.',
        actionLabel: canLoadDemoStorefronts
            ? 'Load demo storefronts'
            : 'Create business profile',
        onAction: () async {
          if (canLoadDemoStorefronts && owner != null) {
            await _loadDemoStorefronts(context, ref, owner: owner, hub: hub);
            return;
          }
          await _showEditBusinessDialog(
            context,
            ref,
            Business(
              id: 'biz-${DateTime.now().millisecondsSinceEpoch}',
              ownerId: owner?.id ?? 'owner-missing',
              name: '',
              category: '',
              description: '',
              address: '',
              phoneNumber: owner?.phoneNumber ?? '',
              imageUrl: '',
              rating: 4.5,
              estimatedDeliveryMinutes: 30,
              latitude: 5.6037,
              longitude: -0.1870,
              tags: const [],
            ),
            isNew: true,
          );
        },
      );
    }

    return ListView(
      children: [
        const SectionHeader(
          title: 'Storefront management',
          subtitle:
              'Each business card below is scoped to the signed-in owner, so counts, products, and incoming orders stay consistent.',
        ),
        if (hasLoadableDemoTemplates) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo storefront bootstrap',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If the seeded Campus Bites and City Pharmacy rows are not editable from this owner account, load owner-linked demo copies here so you can present CRUD actions cleanly.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Load demo storefronts',
                    icon: Icons.storefront_rounded,
                    variant: ButtonVariant.tonal,
                    onPressed: owner == null
                        ? null
                        : () => _loadDemoStorefronts(
                              context,
                              ref,
                              owner: owner,
                              hub: hub,
                            ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final business in ownedBusinesses) ...[
          _BusinessManagementCard(
            business: business,
            products: hub.products
                .where((product) => product.businessId == business.id)
                .toList(growable: false),
            onEditBusiness: () =>
                _showEditBusinessDialog(context, ref, business, isNew: false),
            onAddProduct: () =>
                _showProductDialog(context, ref, businessId: business.id),
            onEditProduct: (product) => _showProductDialog(
              context,
              ref,
              businessId: business.id,
              existing: product,
            ),
            onToggleProduct: (product) async {
              try {
                await ref.read(deliveryHubProvider.notifier).updateProduct(
                      product.copyWith(isAvailable: !product.isAvailable),
                    );
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${product.name} is now ${product.isAvailable ? 'hidden' : 'available'}.',
                    ),
                  ),
                );
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
            onDeleteProduct: (product) async {
              try {
                await ref
                    .read(deliveryHubProvider.notifier)
                    .deleteProduct(product.id);
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${product.name} was deleted.')),
                );
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Future<void> _loadDemoStorefronts(
    BuildContext context,
    WidgetRef ref, {
    required AppUser owner,
    required DeliveryHubState hub,
  }) async {
    final templates = hub.businesses
        .where(
          (business) =>
              business.ownerId != owner.id &&
              (business.name == 'Campus Bites' ||
                  business.name == 'City Pharmacy'),
        )
        .toList(growable: false);
    if (templates.isEmpty) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No demo storefront templates are available to load right now.',
          ),
        ),
      );
      return;
    }

    for (var index = 0; index < templates.length; index++) {
      final template = templates[index];
      final businessId =
          'biz-${owner.id}-${DateTime.now().millisecondsSinceEpoch}-$index';
      final clonedBusiness = template.copyWith(
        id: businessId,
        ownerId: owner.id,
        phoneNumber: owner.phoneNumber ?? template.phoneNumber,
      );
      await ref.read(deliveryHubProvider.notifier).updateBusiness(clonedBusiness);

      final templateProducts = hub.products
          .where((product) => product.businessId == template.id)
          .toList(growable: false);
      for (var productIndex = 0;
          productIndex < templateProducts.length;
          productIndex++) {
        final product = templateProducts[productIndex];
        await ref.read(deliveryHubProvider.notifier).addProduct(
              product.copyWith(
                id:
                    'prd-${businessId}-${DateTime.now().millisecondsSinceEpoch}-$productIndex',
                businessId: businessId,
              ),
            );
      }
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demo storefront copies loaded into this owner account. You can now edit the businesses and products normally.',
        ),
      ),
    );
  }

  Future<void> _showEditBusinessDialog(
    BuildContext context,
    WidgetRef ref,
    Business business, {
    required bool isNew,
  }) async {
    final nameController = TextEditingController(text: business.name);
    final addressController = TextEditingController(text: business.address);
    final descriptionController = TextEditingController(
      text: business.description,
    );
    final categoryController = TextEditingController(text: business.category);
    final phoneController = TextEditingController(text: business.phoneNumber);
    final deliveryMinutesController = TextEditingController(
      text: business.estimatedDeliveryMinutes.toString(),
    );
    final imageController = TextEditingController(text: business.imageUrl);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: Text(
              isNew ? 'Create business profile' : 'Edit business profile',
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Business name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone number'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: deliveryMinutesController,
                    decoration: const InputDecoration(
                      labelText: 'Base preparation and dispatch estimate',
                      helperText:
                          'Use the average number of minutes needed before a rider can normally complete delivery.',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL or local path',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final image = await ref
                            .read(cameraServiceProvider)
                            .captureProofImage(label: 'business');
                        if (image == null) {
                          return;
                        }
                        imageController.text = image.path;
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Use camera / local image'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty ||
                      addressController.text.trim().isEmpty ||
                      phoneController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Business name, address, and phone number are required.',
                        ),
                      ),
                    );
                    return;
                  }
                  final deliveryMinutes =
                      int.tryParse(deliveryMinutesController.text.trim()) ?? 30;
                  try {
                    await ref.read(deliveryHubProvider.notifier).updateBusiness(
                        business.copyWith(
                          name: nameController.text.trim(),
                          address: addressController.text.trim(),
                          description: descriptionController.text.trim(),
                          category: categoryController.text.trim().isEmpty
                              ? 'General'
                              : categoryController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                          imageUrl: imageController.text.trim(),
                          estimatedDeliveryMinutes: deliveryMinutes,
                        ),
                      );
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isNew
                              ? 'Business profile created successfully.'
                              : 'Storefront updated successfully.',
                        ),
                      ),
                    );
                  } catch (error) {
                    if (!dialogContext.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text(error.toString())),
                    );
                  }
                },
                child: Text(isNew ? 'Create' : 'Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProductDialog(
    BuildContext context,
    WidgetRef ref, {
    required String businessId,
    Product? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final categoryController = TextEditingController(
      text: existing?.category ?? '',
    );
    final priceController = TextEditingController(
      text: existing == null ? '' : existing.price.toString(),
    );
    final imageController = TextEditingController(
      text: existing?.imageUrl ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add product' : 'Edit product'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageController,
                      decoration: const InputDecoration(
                        labelText: 'Image URL or local path',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final image = await ref
                              .read(cameraServiceProvider)
                              .captureProofImage(label: 'product');
                          if (image == null) {
                            return;
                          }
                          imageController.text = image.path;
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Use camera / local image'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final parsedPrice =
                        double.tryParse(priceController.text.trim()) ?? 0;
                    if (nameController.text.trim().isEmpty ||
                        categoryController.text.trim().isEmpty ||
                        parsedPrice <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Add a product name, category, and valid price before saving.',
                          ),
                        ),
                      );
                      return;
                    }
                    try {
                      if (existing == null) {
                        await ref.read(deliveryHubProvider.notifier).addProduct(
                            Product(
                              id: 'prd-${DateTime.now().millisecondsSinceEpoch}',
                              businessId: businessId,
                              name: nameController.text.trim(),
                              description: descriptionController.text.trim(),
                              category: categoryController.text.trim(),
                              price: parsedPrice,
                              imageUrl: imageController.text.trim().isEmpty
                                  ? 'https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&w=900&q=80'
                                  : imageController.text.trim(),
                              isAvailable: true,
                              preparationMinutes: 12,
                              imageSource: ProductImageSource.localMock,
                            ),
                          );
                      } else {
                        await ref
                            .read(deliveryHubProvider.notifier)
                            .updateProduct(
                            existing.copyWith(
                              name: nameController.text.trim(),
                              description: descriptionController.text.trim(),
                              category: categoryController.text.trim(),
                              price: parsedPrice,
                              imageUrl: imageController.text.trim(),
                            ),
                          );
                      }
                      if (!dialogContext.mounted) {
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            existing == null
                                ? 'Product created successfully.'
                                : 'Product updated successfully.',
                          ),
                        ),
                      );
                    } catch (error) {
                      if (!dialogContext.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class OwnerAccountTab extends ConsumerWidget {
  const OwnerAccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).currentUser;
    if (user == null) {
      return const EmptyStateView(
        title: 'Account unavailable',
        message: 'Sign in again to manage business-owner account tools.',
        icon: Icons.person_outline_rounded,
      );
    }
    final settings = ref.watch(appSettingsControllerProvider);
    final account = ref.watch(accountPreferencesProvider(user.id));

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Owner account',
                  subtitle:
                      'Profile access, storefront support, and workspace preferences live here.',
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Workspace preferences'),
                  subtitle: Text(
                    'Dark mode ${settings.darkModeEnabled ? 'on' : 'off'}, push notifications ${settings.pushNotificationsEnabled ? 'on' : 'off'}, readable text ${settings.largerTextEnabled ? 'on' : 'off'}.',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.credit_card_outlined),
                  title: const Text('Billing and payout scaffold'),
                  subtitle: Text(
                    account.paymentMethods.isEmpty
                        ? 'No settlement method placeholder saved yet.'
                        : account.paymentMethods.first.details,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Business verification'),
                  subtitle: Text(user.ownerApplicationStatus.helperCopy(AppRole.owner)),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Open account center',
                  icon: Icons.manage_accounts_outlined,
                  onPressed: () => context.push(AppRoutes.accountHub),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Open settings',
                  variant: ButtonVariant.tonal,
                  icon: Icons.settings_outlined,
                  onPressed: () => context.push(AppRoutes.settings),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Call support',
                  variant: ButtonVariant.outlined,
                  icon: Icons.support_agent_rounded,
                  onPressed: () async {
                    final result = await ref
                        .read(phoneServiceProvider)
                        .tryCallNumber(AppConstants.supportPhone);
                    if (!context.mounted || result.success) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.message)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BusinessManagementCard extends StatelessWidget {
  const _BusinessManagementCard({
    required this.business,
    required this.products,
    required this.onEditBusiness,
    required this.onAddProduct,
    required this.onEditProduct,
    required this.onToggleProduct,
    required this.onDeleteProduct,
  });

  final Business business;
  final List<Product> products;
  final VoidCallback onEditBusiness;
  final VoidCallback onAddProduct;
  final ValueChanged<Product> onEditProduct;
  final ValueChanged<Product> onToggleProduct;
  final ValueChanged<Product> onDeleteProduct;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: business.name,
              subtitle:
                  '${business.category} • Base prep and dispatch estimate ${business.estimatedDeliveryMinutes} min',
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SafeNetworkImage(
                imageUrl: business.imageUrl,
                height: 170,
                width: double.infinity,
                placeholderIcon: Icons.storefront_rounded,
                placeholderLabel:
                    business.name.isEmpty ? 'Business image' : business.name,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              business.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Text(business.address),
            const SizedBox(height: 6),
            Text(
              business.phoneNumber.isEmpty
                  ? 'No storefront phone number yet'
                  : business.phoneNumber,
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Edit storefront',
              icon: Icons.edit_outlined,
              onPressed: onEditBusiness,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Products',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onAddProduct,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (products.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'No products added for this storefront yet.',
                ),
              )
            else
              ...products.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: const Color(0xFFF8FAFC),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SafeNetworkImage(
                          imageUrl: product.imageUrl,
                          width: 52,
                          height: 52,
                        ),
                      ),
                      title: Text(product.name),
                      subtitle: Text(
                        'GHS ${product.price.toStringAsFixed(2)} • ${product.category} • ${product.isAvailable ? 'Available' : 'Hidden'}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            onPressed: () => onToggleProduct(product),
                            icon: Icon(
                              product.isAvailable
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          IconButton(
                            onPressed: () => onEditProduct(product),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => onDeleteProduct(product),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroOwnerCard extends StatelessWidget {
  const _HeroOwnerCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF2563EB), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
